require 'zip'

module Audio
  class SplitGaplessAudio
    include Utils::StrongMemoize

    def initialize(recitation_id, base_path = nil)
      @recitation = Audio::Recitation.find(recitation_id)
      @base_path = base_path || "data/audio/#{recitation_id}/mp3"
      FileUtils.mkdir_p @base_path
      FileUtils.mkdir_p "#{@base_path}/surah"
      FileUtils.mkdir_p "#{@base_path}/ayah-by-ayah"
    end

    def split_surah(chapter_id, ayah_from: nil, ayah_to: nil)
      segments = Audio::Segment
                   .where(
                     chapter_id: chapter_id,
                     audio_recitation: @recitation
                   ).order('verse_number ASC')

      if ayah_from.present? && ayah_to.present?
        segments = segments.where(
          verse_number: ayah_from..ayah_to
        )
      end

      segments.each do |segment|
        from = segment.timestamp_from / 1000.0
        to = segment.timestamp_to / 1000.0
        ayah_path = ayah_audio_path(chapter_id, segment.verse_number)
        next if File.exist?(ayah_path)
        binding.pry if @debug.nil?
        puts "Splitting #{chapter_id}:#{segment.verse_number} timing range is  #{from} - #{to}"

        split_ayah(
          from,
          to,
          load_surah_audio(chapter_id),
          ayah_path
        )
      end

      prepare_surah_audio_zip(chapter_id)
    end

    def load_surah_audio(chapter_id)
      strong_memoize "audio_#{chapter_id}_#{@recitation.id}" do
        path = surah_audio_file(chapter_id)
        download_audio_file(chapter_id, path) unless File.exist?(path)
        path
      end
    end

    def surah_audio_file(chapter_id)
      "#{@base_path}/#{chapter_id.to_s.rjust(3, '0')}.mp3"
    end

    def split_ayah(from, to, input, output)
      `ffmpeg -i #{input} -ss #{from} -to #{to} -c copy #{output}`
    end

    def ayah_audio_path(chapter_id, verse_number)
      FileUtils.mkdir_p "#{@base_path}/ayah-by-ayah"
      "#{@base_path}/ayah-by-ayah/#{chapter_id.to_s.rjust(3, '0')}#{verse_number.to_s.rjust(3, '0')}.mp3"
    end

    def download_audio_file(chapter_id, path)
      file_url = @recitation.chapter_audio_files.where(chapter_id: chapter_id).first.audio_url
      uri = URI(file_url)
      Net::HTTP.version_1_2 # make sure we use higher HTTP protocol version than 1.0

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      puts "Downloading #{file_url} to #{path}"

      response = http.get(file_url)
      File.open(path, "wb") do |file|
        file << response.body
      end
    end

    def prepare_surah_audio_zip(chapter_id)
      surah_folder = "#{@base_path}/surah/#{chapter_id}"
      FileUtils.mkdir_p surah_folder

      ayah_pattern = "#{@base_path}/ayah-by-ayah/#{chapter_id.to_s.rjust(3, '0')}*.mp3"
      ayah_files = Dir.glob(ayah_pattern)

      ayah_files.each do |ayah_file|
        filename = File.basename(ayah_file)
        destination = "#{surah_folder}/#{filename}"
        FileUtils.cp(ayah_file, destination) unless File.exist?(destination)
      end

      zip_surah_folder(surah_folder)
    end

    def zip_surah_folder(surah_folder)
      zip_path = "#{surah_folder}.zip"
      FileUtils.rm_f(zip_path)

      Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
        Dir.glob("#{surah_folder}/*").each do |file|
          filename = File.basename(file)
          zipfile.add(filename, file)
        end
      end

      zip_path
    end
  end
end