module Audio
  class SplitGapelessAudio
    include Utils::StrongMemoize

    def initialize(recitation_id, base_path = nil)
      @recitation = Audio::Recitation.find(recitation_id)
      @base_path = base_path || "data/audio/#{recitation_id}/mp3"
      FileUtils.mkdir_p @base_path
    end

    def split_surah(chapter_id)
      Audio::Segment.where(chapter_id: chapter_id, audio_recitation: @recitation)
                    .order('verse_number ASC')
                    .each do |segment|
        from = segment.timestamp_from / 1000.0
        to = segment.timestamp_to / 1000.0

        split_ayah(
          from,
          to,
          load_surah_audio(chapter_id),
          ayah_audio_path(chapter_id, segment.verse_number)
        )
      end
    end

    def load_surah_audio(chapter_id)
      strong_memoize "audio_#{chapter_id}_#{@recitation.id}" do
        path = surah_audio_file(chapter_id)
        download_audio_file(chapter_id, path) unless File.exist?(path)

        path
      end
    end

    def surah_audio_file(chapter_id)
      "#{@base_path}/#{chapter_id}.mp3"
    end

    def split_ayah(from, to, input, output)
      `ffmpeg -i #{input} -ss #{from} -to #{to} -c copy #{output}`
    end

    def ayah_audio_path(chapter_id, verse_number)
      FileUtils.mkdir_p "#{@base_path}/ayah-by-ayah/#{chapter_id}"
      "#{@base_path}/ayah-by-ayah/#{chapter_id}/#{chapter_id.to_s.rjust(3, '0')}#{verse_number.to_s.rjust(3, '0')}.mp3"
    end

    def download_audio_file(chapter_id, path)
      file_url = @recitation.chapter_audio_files.where(chapter_id: chapter_id).first.audio_url
      uri = URI(file_url)
      Net::HTTP.version_1_2 # make sure we use higher HTTP protocol version than 1.0

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      response = http.get(file_url)
      File.open(path, "wb") do |file|
        file << response.body
      end
    end
  end
end