namespace :audio_optimize do
  task optimize_mp3: :environment do
    require 'open3'
    reciter_name = "Maher al-Muaiqly"
    base_path = "/Volumes/Data/qul-segments/audio/65"
    mp3_path = "#{base_path}/mp3"
    optimized_path = "#{base_path}/optimized"
    wav_path = "#{base_path}/wav"

    def encode_to_wav(mp3_path, wav_path)
      if File.exist?(wav_path)
        puts "#{wav_path} already exists"
        return
      end

      puts "Encoding #{mp3_path} to #{wav_path}"
      `ffmpeg -i #{mp3_path} -ac 1 -ar 16000 -c:a pcm_s16le #{wav_path}`
    end

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

    def normalize_audio(file, output_file, analysis, meta_data, encoding: :cbr)
      metadata_flags = meta_data.flat_map do |key, value|
        ['-metadata', "#{key}=#{value}"]
      end

      audio_opts = case encoding
                   when :vbr
                     # LAME VBR quality setting (-q:a), lower is better quality
                     ['-q:a', '5'] # ~150 kbps VBR good balance for speech
                   when :cbr
                     ['-b:a', '128k'] # 128 kbps CBR
                   else
                     raise ArgumentError, "Unsupported encoding: #{encoding}"
                   end

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
        *audio_opts,
        '-vn',
        '-map_metadata', '-1',
        '-map_chapters', '-1',
        *metadata_flags,
        output_file
      ]

      system(*command)
    end

    FileUtils.mkdir_p(optimized_path)
    FileUtils.mkdir_p(wav_path)

    (1..114).each do |num|
      chapter = Chapter.find(num)

      file_path = num.to_s.rjust(3, '0')
      file = "#{mp3_path}/#{file_path}.mp3"
      optimized = "#{optimized_path}/#{file_path}.mp3"
      wav = "#{wav_path}/#{file_path}.wav"

      if !File.exist?(optimized)
        puts "Processing Surah #{num} - #{file_path}.mp3"

        begin
          analysis = analyze_loudness(file)

          puts analysis

          meta_data = {
            title: "Surah #{chapter.name_simple}",
            artist: reciter_name,
            album: 'Quran',
            genre: 'Quran',
            track: "#{chapter.id}/114",
            comment: 'qul.tarteel.ai'
          }
          normalize_audio(
            file,
            optimized,
            analysis,
            meta_data,
            encoding: :vbr
          )
        rescue TypeError => e
          puts "Error Processing surah #{chapter.id}"
        end
      end

      encode_to_wav(file, wav)
    end
  end

  task encode_wav_to_mp3: :environment do
    require "shellwords"
    base_path = "/Volumes/Data/qul-segments/audio/65"
    mp3_path = "#{base_path}/final/mp3"
    wav_path = "#{base_path}/wav"

    FileUtils.mkdir_p(mp3_path)

    def encode_to_mp3(input_wav, output_mp3, meta_data = {})
      return puts "#{File.basename(output_mp3)} already exists" if File.exist?(output_mp3)

      puts "Re-encoding #{File.basename(input_wav)} to MP3..."
      # Keep mono + 16kHz, high quality MP3
      args = "-ac 1 -ar 16000 -codec:a libmp3lame -b:a 128k"

      # Add metadata options
      meta_args = meta_data.map do |key, value|
        %Q(-metadata #{key}=#{Shellwords.escape(value.to_s)})
      end.join(" ")

      system("ffmpeg -loglevel error -y -i #{Shellwords.escape(input_wav)} #{args} #{meta_args} #{Shellwords.escape(output_mp3)}")
    end

    reciter_name = "Maher al-Muaiqly"

    (1..114).each do |num|
      chapter = Chapter.find(num)

      meta_data = {
        title: "Surah #{chapter.name_simple}",
        artist: reciter_name,
        album: 'Quran',
        genre: 'Quran',
        track: "#{chapter.id}/114",
        comment: 'qul.tarteel.ai'
      }

      file_path = num.to_s.rjust(3, '0')
      input_wav = "#{wav_path}/#{file_path}.wav"
      output_mp3 = "#{mp3_path}/#{file_path}.mp3"
      encode_to_mp3(input_wav, output_mp3, meta_data)
    end
  end
end
