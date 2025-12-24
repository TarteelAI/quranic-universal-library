require 'wahwah'
require 'fileutils'
require 'json'
require 'mime/types'
require 'net/http'
require 'open3'
require 'uri'

module Audio
  class AudioFileMetaData
    attr_reader :tmp_dir,
                :recitation

    def initialize(recitation:)
      @recitation = recitation
      @tmp_dir = "tmp/audio_meta_data/#{recitation.id}"
      FileUtils.mkdir_p(tmp_dir)
    end

    def update_meta_data(options={})
      if recitation.one_ayah?
        update_ayah_audio_meta_data(chapter_id: options[:chapter_id], force: options[:force])
        segments = AudioSegment::AyahByAyah.new(recitation)
        segments.track_repetition(chapter_id: options[:chapter_id])
      else
        update_surah_audio_meta_data(chapter_id: options[:chapter_id], force: options[:force])
        segments = AudioSegment::SurahBySurah.new(recitation)
        segments.track_repetition(chapter_id: options[:chapter_id])
      end

      clean_up
    end

    protected

    def update_surah_audio_meta_data(chapter_id: nil, force: false)
      audio_files = Audio::ChapterAudioFile.where(audio_recitation: recitation)

      if chapter_id
        audio_files = audio_files.where(chapter_id: chapter_id)
      end

      audio_files.each do |audio_file|
        next if !force && audio_file.has_audio_meta_data?

        url = audio_file.audio_url
        audio_file.update_segment_percentile

        if meta_response = fetch_audio_file_meta_data(url)
          duration = meta_response[:duration]
          audio_file.attributes = {
            file_size: meta_response[:size],
            bit_rate: meta_response[:bit_rate],
            duration: duration&.round(2),
            duration_ms: duration ? (duration * 1000).to_i : nil,
            mime_type: meta_response[:mime_type],
            meta_data: prepare_surah_audio_meta_data(
              audio_file: audio_file,
              year: meta_response[:year]
            )
          }
        end

        audio_file.save(validate: false)
      end
    end

    def update_ayah_audio_meta_data(chapter_id: nil, force: false)
      audio_files = AudioFile
                      .includes(:verse, :chapter)
                      .where(recitation_id: recitation.id)

      if chapter_id
        audio_files = audio_files.where(chapter_id: chapter_id)
      end

      audio_files.find_each do |audio_file|
        next if !force && audio_file.has_audio_meta_data?
        url = audio_file.audio_url

        if meta_response = fetch_audio_file_meta_data(url)
          duration = meta_response[:duration]
          audio_file.attributes = {
            file_size: meta_response[:size],
            bit_rate: meta_response[:bit_rate],
            duration: duration&.round(2),
            duration_ms: duration ? (duration * 1000).to_i : nil,
            mime_type: meta_response[:mime_type],
            meta_data: prepare_surah_meta_data(
              audio_file: audio_file,
              year: meta_response[:year]
            )
          }

          audio_file.save(validate: false)
        end
      end
    end

    def clean_up
      FileUtils.rm_rf(tmp_dir)
    end

    def prepare_surah_meta_data(audio_file:, year:)
      existing_meta = audio_file.meta_data || {}
      chapter = audio_file.chapter

      existing_meta.with_defaults_values(
        {
          album: "#{recitation.name} Quran recitation",
          genre: "Quran",
          title: chapter.name_simple,
          track: "#{chapter.chapter_number}/114",
          artist: recitation.name,
          year: year
        }
      )

      existing_meta[:comment] = 'https://qul.tarteel.ai/'
      existing_meta.to_h
    end

    def prepare_surah_audio_meta_data(audio_file:, year:)
      meta_data = audio_file.meta_data || {}
      chapter = audio_file.chapter

      meta_data.with_defaults_values(
        {
          album: "#{recitation.name} Quran recitation",
          genre: "Quran",
          title: chapter.name_simple,
          track: "114/#{chapter.id}",
          artist: recitation.name,
          year: year
        }
      )

      meta_data[:comment] = 'https://qul.tarteel.ai/'
      meta_data.to_h
    end

    def fetch_audio_file_meta_data(url)
      headers = fetch_headers(url)
      return false if headers[:not_found]

      probed = probe_with_ffprobe(url)
      if probed && (probed[:duration] || probed[:bit_rate])
        return {
          size: headers[:size],
          mime_type: headers[:mime_type] || mime_type_from_url(url),
          duration: probed[:duration],
          bit_rate: probed[:bit_rate],
          year: probed[:year]
        }
      end

      request = fetch_bytes(url, 5.megabytes)
      return false unless request

      body = request.body
      if request.is_a?(Net::HTTPNotFound) || body.to_s.include?('Not Found')
        return false
      else
        tmp_file_name = "audio-#{Time.now.to_i}.mp3"
        File.open("#{tmp_dir}/#{tmp_file_name}", "wb") do |file|
          file << body
        end
        file_path = "#{tmp_dir}/#{tmp_file_name}"

        meta = WahWah.open(file_path)
        duration = meta.duration || probe_with_ffprobe(file_path)&.dig(:duration)
        bit_rate = meta.bitrate || probe_with_ffprobe(file_path)&.dig(:bit_rate)

        {
          size: headers[:size] || request['content-length']&.to_i,
          mime_type: headers[:mime_type] || mime_type_from_url(url) || MIME::Types.type_for(file_path).first&.content_type,
          duration: duration&.to_f,
          bit_rate: bit_rate,
          year: meta.year || probe_with_ffprobe(file_path)&.dig(:year)
        }
      end
    end

    def fetch_bytes(url, size)
      uri = URI(url)
      get_request(uri, { 'Range' => "bytes=0-#{size - 1}" })
    end

    def fetch_headers(url)
      uri = URI(url)
      head = head_request(uri)
      return { not_found: true } if head.is_a?(Net::HTTPNotFound)

      mime_type = head&.[]('content-type')&.split(';')&.first
      size = head&.[]('content-length')&.to_i

      if size.to_i <= 0
        ranged = get_request(uri, { 'Range' => 'bytes=0-0' })
        if ranged && ranged['content-range']
          size = ranged['content-range'].split('/').last.to_i
        else
          size = ranged&.[]('content-length')&.to_i
        end
        mime_type ||= ranged&.[]('content-type')&.split(';')&.first
      end

      { size: size.to_i > 0 ? size.to_i : nil, mime_type: mime_type }
    rescue StandardError
      {}
    end

    def probe_with_ffprobe(source)
      stdout, _stderr, status = Open3.capture3(
        'ffprobe',
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_entries',
        'format=duration,bit_rate:format_tags=year,date',
        '-i',
        source
      )

      return nil unless status.success? && stdout.to_s.strip.length.positive?

      data = JSON.parse(stdout)
      format = data['format'] || {}
      duration = format['duration']&.to_f
      bit_rate_bps = format['bit_rate']&.to_f
      tags = format['tags'] || {}
      year_raw = tags['year'] || tags['date'] || tags['YEAR'] || tags['DATE']
      year = year_raw.to_s[/\d{4}/]

      {
        duration: duration && duration.positive? ? duration : nil,
        bit_rate: bit_rate_bps && bit_rate_bps.positive? ? (bit_rate_bps / 1000.0) : nil,
        year: year
      }
    rescue StandardError
      nil
    end

    def mime_type_from_url(url)
      MIME::Types.type_for(url).first&.content_type
    end

    def head_request(uri)
      request_with_redirects(uri, Net::HTTP::Head, {})
    end

    def get_request(uri, headers)
      request_with_redirects(uri, Net::HTTP::Get, headers)
    end

    def request_with_redirects(uri, request_class, headers)
      redirects = 0

      while redirects < 5
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 10
        http.read_timeout = 30

        request = request_class.new(uri.request_uri, headers)
        response = http.request(request)

        if response.is_a?(Net::HTTPRedirection) && response['location'].present?
          uri = URI(response['location'])
          redirects += 1
          next
        end

        return response
      end

      nil
    rescue StandardError
      nil
    end
  end
end