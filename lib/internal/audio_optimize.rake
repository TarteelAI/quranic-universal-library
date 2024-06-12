namespace :audio_optimize do
  task run: :environment do
    #base_path = "/Volumes/Development/community-data/segments-data/mishari-streaming"
    base_path = "../community-data/segments-data/Sheikh-Yasser-Al-Dosari/"

    def normalize_volume(file, output_path)
      output = `ffmpeg -i '#{file}' -af "volumedetect" -f null /dev/null 2>&1`
      raise "Error getting audio volume from #{file} (#{$?})" unless $?.success?
      max_volume = output.scan(/max_volume: ([\-\d\.]+) dB/).flatten.first
      mean_volume = output.scan(/mean_volume: ([\-\d\.]+) dB/).flatten.first
      return if !max_volume || !mean_volume
      max_volume = max_volume.to_f
      mean_volume = mean_volume.to_f
      target_volume = -11.8
      adjustment = target_volume - mean_volume
      output_file = "/tmp/#{File.basename(file)}"
      #result = system(*['ffmpeg', '-i', file, '-af', "volume=#{adjustment}dB", '-c:v', 'copy', output_file])
      result = system(*['ffmpeg', '-i', file, '-af', "loudnorm=I=#{target_volume}:TP=-1.5:LRA=11dB", '-c:v', 'copy', output_file])

      raise "Error normalizing audio volume of #{file}" unless result

      FileUtils.mv(output_file, output_path)
    end

    FileUtils.mkdir_p("#{base_path}/optimized/mp3")
    FileUtils.mkdir_p("#{base_path}/optimized/opus")

    Dir["#{base_path}/*.mp3"].each do |input|
      surah = input[/\d+/].to_i
      fixed_volume = "#{base_path}/fixed_volume/#{surah}.mp3"
      mp3 = "#{base_path}/optimized/mp3/#{surah}"
      opus = "#{base_path}/optimized/opus/#{surah}"

      normalize_volume(input, fixed_volume)

      #96 kbps is recommended when streaming is important.
      # https://scribbleghost.net/2022/12/29/convert-audio-to-opus-with-ffmpeg/
      `ffmpeg -y -i #{fixed_volume} -map 0:a:0 -b:a 96k #{mp3}.mp3`

      # Opus version
      #`ffmpeg -i #{input} -c:a libopus -b:a 96k #{opus}.opus`
    end
  end

  task optimize_streaming_audio: :environment do
    base_path = "/Volumes/Development/qdc/community-data/segments-data/streaming_audio"
    result_base_path = "#{base_path}/result"
    timing_base_path = "#{result_base_path}/timings"

    def normalize_volume(file, output_path)
      output = `ffmpeg -i '#{file}' -af "volumedetect" -f null /dev/null 2>&1`
      raise "Error getting audio volume from #{file} (#{$?})" unless $?.success?
      max_volume = output.scan(/max_volume: ([\-\d\.]+) dB/).flatten.first
      mean_volume = output.scan(/mean_volume: ([\-\d\.]+) dB/).flatten.first
      return if !max_volume || !mean_volume
      max_volume = max_volume.to_f
      mean_volume = mean_volume.to_f
      target_volume = -11.8
      adjustment = target_volume - mean_volume
      output_file = "/tmp/#{File.basename(file)}"
      #result = system(*['ffmpeg', '-i', file, '-af', "volume=#{adjustment}dB", '-c:v', 'copy', output_file])
      result = system(*['ffmpeg', '-i', file, '-af', "loudnorm=I=#{target_volume}:TP=-1.5:LRA=11dB", '-c:v', 'copy', output_file])

      raise "Error normalizing audio volume of #{file}" unless result

      FileUtils.mv(output_file, output_path)
    end

    def prepare_timing_file(base_path, timing_path, surah)
      files = Dir["#{base_path}/*.mp3"]
      files = files.sort_by do |f|
        f.split('/').last.split('.').first.to_i
      end

      File.open("#{timing_path}/#{surah}.txt", "wb") do |file|
        files.each do |audio|
          file.puts "file '#{audio}'"
        end
      end

      "#{timing_path}/#{surah}.txt"
    end

    def merge_surah_audio(timing_file, result_file)
      `ffmpeg -f concat -safe 0 -i #{timing_file} -c copy #{result_file}`
    end

    1.upto(114).each do |surah|
      surah_path = "#{base_path}/#{surah}"
      next if File.exist?("#{result_base_path}/#{surah}.mp3")

      FileUtils.mkdir_p("#{surah_path}/optimized")
      FileUtils.mkdir_p("#{surah_path}/normalized")

      Dir["#{surah_path}/*.mp3"].each do |input|
        n = input.split(".mp3").first.split('/').last
        output = "#{surah_path}/optimized/#{n}.mp3"

        `ffmpeg -y -i #{input} -map 0:a:0 -b:a 96k #{output}`
      end

      # Normalize the audio path
      Dir["#{surah_path}/optimized/*.mp3"].each do |input|
        normalize_volume input, input.gsub('optimized', 'normalized')
      end

      timing_file = prepare_timing_file "#{surah_path}/normalized", timing_base_path, surah
      merge_surah_audio(timing_file, "#{result_base_path}/#{surah}.mp3")
    end
  end

  task import_segments: :environment do
    def parse(id, segments, audio_length)
      chapter = Chapter.find id
      audio_recitation_id = 175

      audio_file = Audio::ChapterAudioFile.where(
        audio_recitation_id: audio_recitation_id,
        chapter: chapter
      ).first_or_create

      previous = 0
      segments.each_with_index do |v, i|
        verse = chapter.verses.find_by(verse_number: i+1)
        last = segments[i+1] || audio_length
        start = v

        segment = Audio::Segment.where(verse: verse, audio_recitation_id: audio_recitation_id).first_or_initialize
        segment.set_timing(start, last, verse)
        segment.audio_file = audio_file
        segment.save
      end
    end

    def fetch_segments(i)
      url = "https://www.wordofallah.com/index.php?param=asynch.surah&do=surah&surah=#{i}&qari=0&0.2393245676960707"

      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient.get(url)
      end

      data = JSON.parse response.body
      data.last.values.map(&:to_i)
    end

    def calculate_duration(i)
      base_path = "/Volumes/Development/qdc/community-data/segments-data/streaming_audio"
      result_base_path = "#{base_path}/result"

      audio_url = "#{result_base_path}/#{i}.mp3"
      result = `ffmpeg -i #{audio_url} 2>&1 | egrep "Duration"`
      matched = result.match(/Duration:\s(?<h>(\d+)):(?<m>(\d+)):(?<s>(\d+))/)
      duration = (matched[:h].to_i * 3600) + (matched[:m].to_i * 60) + matched[:s].to_i

      duration * 1000
    end

    1.upto(78) do |i|
      parse i, fetch_segments(i), calculate_duration(i)
    end
  end
end
