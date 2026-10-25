require 'open3'
require 'json'
require 'net/http'

module Audio
  class AudioFileMetaData
    attr_reader :recitation

    def initialize(recitation:)
      @recitation = recitation
    end

    def update_meta_data(options={})
      if recitation.one_ayah?
        update_ayah_audio_meta_data(chapter_id: options[:chapter_id], force: options[:force])
        segments = AudioSegment::AyahByAyah.new(recitation)
      else
        update_surah_audio_meta_data(chapter_id: options[:chapter_id], force: options[:force])
        segments = AudioSegment::SurahBySurah.new(recitation)
      end

      segments.track_repetition(chapter_id: options[:chapter_id])
    end

    protected

    def update_surah_audio_meta_data(chapter_id: nil, force: false)
      audio_files = Audio::ChapterAudioFile.where(audio_recitation: recitation)
      audio_files = audio_files.where(chapter_id: chapter_id) if chapter_id

      audio_files.each do |audio_file|
        next if !force && audio_file.has_audio_meta_data?

        audio_file.update_segment_percentile
        update_audio_file_meta_data(audio_file)
      end
    end

    def update_ayah_audio_meta_data(chapter_id: nil, force: false)
      audio_files = AudioFile
                      .includes(:verse, :chapter)
                      .where(recitation_id: recitation.id)
      audio_files = audio_files.where(chapter_id: chapter_id) if chapter_id

      audio_files.find_each do |audio_file|
        next if !force && audio_file.has_audio_meta_data?

        update_audio_file_meta_data(audio_file)
      end
    end

    def update_audio_file_meta_data(audio_file)
      url = "#{audio_file.audio_url}?#{Time.now.to_i}"
      meta = fetch_audio_file_metadata(url)
      return unless meta

      meta[:etag] = fetch_remote_etag(url)
      duration = (meta[:duration_ms].to_f / 1000)

      audio_file.attributes = {
        file_size: meta[:size_bytes],
        bit_rate: meta[:bitrate],
        duration: duration.round(2),
        duration_ms: meta[:duration_ms].to_i,
        mime_type: meta[:mime_type],
        meta_data: prepare_meta_data(audio_file: audio_file, meta: meta)
      }

      # Only moves when the audio itself changed, so saving this record for any
      # other reason doesn't invalidate the file for every client.
      audio_file.sync_content_version(meta)
      audio_file.save(validate: false)
    end

    # The CDN's own content hash, when it gives us one. Cheaper and more exact
    # than anything we can derive from the probed values.
    def fetch_remote_etag(url, redirects_left = 2)
      uri = URI.parse(url)
      return nil unless uri.is_a?(URI::HTTP)

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: 5,
        read_timeout: 5
      ) do |http|
        http.request(Net::HTTP::Head.new(uri))
      end

      if response.is_a?(Net::HTTPRedirection) && response['location'].present? && redirects_left > 0
        return fetch_remote_etag(URI.join(url, response['location']).to_s, redirects_left - 1)
      end

      response['etag'].presence&.delete('"')
    rescue StandardError
      nil
    end

    def prepare_meta_data(audio_file:, meta:)
      if recitation.one_ayah?
        prepare_ayah_file_meta_data(audio_file: audio_file, meta: meta)
      else
        prepare_surah_file_meta_data(audio_file: audio_file, meta: meta)
      end
    end

    def prepare_surah_file_meta_data(audio_file:, meta:)
      meta_data = audio_file.meta_data || {}
      chapter = audio_file.chapter

      meta_data.with_defaults_values(
        {
          album: "#{recitation.name} Quran recitation",
          genre: "Quran",
          title: chapter.name_simple,
          track: "#{chapter.chapter_number}/114",
          artist: recitation.name,
          year: meta[:year]
        }
      )

      meta_data[:comment] = 'https://qul.tarteel.ai/'
      meta_data.to_h
    end

    def prepare_ayah_file_meta_data(audio_file:, meta:)
      meta_data = audio_file.meta_data || {}
      chapter = audio_file.chapter
      ayah_number = audio_file.verse_number

      meta_data.with_defaults_values(
        {
          album: "#{recitation.name} Quran recitation",
          genre: "Quran",
          title: "#{chapter.name_simple} #{ayah_number}",
          track: "#{chapter.verses_count}/#{ayah_number}",
          artist: recitation.name,
          year: meta[:year]
        }
      )

      meta_data[:comment] = 'https://qul.tarteel.ai/'
      meta_data.to_h
    end

    def fetch_audio_file_metadata(url)
      stdout, status = Open3.capture2(
        "ffprobe",
        "-v", "quiet",
        "-print_format", "json",
        "-show_format",
        "-show_streams",
        url,
      )

      return nil unless status.success?

      data = JSON.parse(stdout)

      format = data["format"] || {}
      stream = data["streams"]&.find { |s| s["codec_type"] == "audio" } || {}

      tags = format["tags"] || stream["tags"] || {}

      format_name = format["format_name"] || stream["codec_name"]

      mime_type = case format_name
                  when "mp3" then "audio/mpeg"
                  when "wav" then "audio/wav"
                  when "flac" then "audio/flac"
                  when "ogg" then "audio/ogg"
                  when "aac" then "audio/aac"
                  when "mp4,m4a,3gp,3g2,mj2" then "audio/mp4"
                  end

      {
        artist: tags["artist"],
        year: tags["date"] || tags["year"],
        size_bytes: format["size"]&.to_i,
        duration_ms: (format["duration"].to_f * 1000).round,
        sample_rate: stream["sample_rate"]&.to_i,
        bitrate: (
          stream["bit_rate"] ||
          format["bit_rate"]
        )&.to_i,
        format: format_name,
        mime_type: mime_type
      }
    end
  end
end
