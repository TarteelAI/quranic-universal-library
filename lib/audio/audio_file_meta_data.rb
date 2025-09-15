require 'wahwah'

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
          file = meta_response[:file]

          meta = WahWah.open(file)
          duration = (meta.duration || calculate_duration(file)).to_f

          audio_file.attributes = {
            file_size: meta_response[:size].to_i,
            bit_rate: meta.bitrate,
            duration: duration.round(2),
            duration_ms: (duration * 1000).to_i,
            mime_type: MIME::Types.type_for(file).first.content_type,
            meta_data: prepare_surah_audio_meta_data(
              audio_file: audio_file,
              meta: meta
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
          file = meta_response[:file]

          meta = WahWah.open(file)
          duration = (meta.duration || calculate_duration(file)).to_f

          audio_file.attributes = {
            file_size: meta_response[:size].to_i,
            bit_rate: meta.bitrate,
            duration: duration.round(2),
            duration_ms: (duration * 1000).to_i,
            mime_type: MIME::Types.type_for(file).first.content_type,
            meta_data: prepare_surah_meta_data(
              audio_file: audio_file,
              meta: meta
            )
          }

          audio_file.save(validate: false)
        end
      end
    end

    def clean_up
      FileUtils.rm_rf(tmp_dir)
    end

    def prepare_surah_meta_data(audio_file:, meta:)
      existing_meta = audio_file.meta_data || {}
      chapter = audio_file.chapter

      existing_meta.with_defaults_values({
                                           album: "#{recitation.name} Quran recitation",
                                           genre: "Quran",
                                           title: chapter.name_simple,
                                           track: "#{chapter.chapter_number}/114",
                                           artist: recitation.name,
                                           year: meta.year
                                         })

      existing_meta[:comment] = 'https://qul.tarteel.ai/'
      existing_meta.to_h
    end

    def prepare_surah_audio_meta_data(audio_file:, meta:)
      meta_data = audio_file.meta_data || {}
      chapter = audio_file.chapter

      meta_data.with_defaults_values(
        {
          album: "#{recitation.name} Quran recitation",
          genre: "Quran",
          title: chapter.name_simple,
          track: "114/#{chapter.id}",
          artist: recitation.name,
          year: meta.year
        }
      )

      meta_data[:comment] = 'https://qul.tarteel.ai/'
      meta_data.to_h
    end

    def calculate_duration(audio_file)
      # ffmpeg -i https://download.quranicaudio.com/quran/abdullaah_3awwaad_al-juhaynee/001.mp3 2>&1 | egrep "Duration"

      result = `ffmpeg -i #{audio_file} 2>&1 | egrep "Duration"`
      matched = result.match(/Duration:\s(?<h>(\d+)):(?<m>(\d+)):(?<s>(\d+))/)

      (matched[:h].to_i * 3600) + (matched[:m].to_i * 60) + matched[:s].to_i
    rescue Exception => e
      nil
    end

    def fetch_audio_file_meta_data(url)
      request = fetch_bytes(url, 5.megabyte)
      body = request.body

      if body.to_s.include?("Not Found")
        return false
      else
        tmp_file_name = "audio-#{Time.now.to_i}.mp3"
        File.open("#{tmp_dir}/#{tmp_file_name}", "wb") do |file|
          file << body
        end

        {
          file: "#{tmp_dir}/#{tmp_file_name}",
          size: request.response.header['content-length']
        }
      end
    end

    def fetch_bytes(url, size)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get(url, { 'Range' => "bytes=0-#{size}" })
    end
  end
end