namespace :audio_optimize do
  task optimize_mp3: :environment do
    require 'open3'

    def analyze_loudness(file)
      command = [
        'ffmpeg',
        '-i', file,
        '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json',
        '-f', 'null', '-'
      ]

      stdout, stderr, _ = Open3.capture3(*command)
      json_str = stderr[/\{[\s\S]*?\}/]
      JSON.parse(json_str)
    end

    def normalize_audio(file, output_file, analysis)
      command = [
        'ffmpeg',
        '-i', file,
        '-af', [
          "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=#{analysis["input_i"]}",
          "measured_TP=#{analysis["input_tp"]}",
          "measured_LRA=#{analysis["input_lra"]}",
          "measured_thresh=#{analysis["input_thresh"]}",
          "offset=#{analysis["target_offset"]}:linear=true:print_format=summary"
        ].join(':'),
        '-c:a', 'libmp3lame',
        '-b:a', '128k',
        '-vn',
        '-map_metadata', '-1',
        '-map_chapters', '-1',
        '-metadata', 'comment=qul.tarteel.ai',
        output_file
      ]

      system(*command)
    end

    def optimize(file, output_file)
      target_volume = -16

      result = system(*[
        'ffmpeg',
        '-i', file,
        '-af', "loudnorm=I=#{target_volume}:TP=-1.5:LRA=11",
        '-c:a', 'libmp3lame',
        '-b:a', '128k',
        '-vn', # remove video/cover art
        '-map_metadata', '-1', # strip all existing metadata
        '-map_chapters', '-1', # remove chapters
        '-metadata', 'comment=qul.tarteel.ai', # add custom comment
        output_file
      ])
    end

    base_path = "/Volumes/Data/qul-segments/audio/saddiq_minshawi_mujawwad/mp3"
    optimized_path = "/Volumes/Data/qul-segments/audio/saddiq_minshawi_mujawwad/optimized"
    FileUtils.mkdir_p(optimized_path)

    (1..114).each do |num|
      next if num != 9

      file_path = num.to_s.rjust(3, 0)
      file = "#{base_path}/#{file_path}.mp3"
      optimized = "#{optimized_path}/#{file_path}.mp3"

      analysis = analyze_loudness(file)
      normalize_audio(file, optimized, analysis)
    end
  end

  task run: :environment do
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
      output_file = "/tmp/#{File.basename(file)}"
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

      # 96 kbps is recommended when streaming is important.
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
      output_file = "/tmp/#{File.basename(file)}"
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
end
