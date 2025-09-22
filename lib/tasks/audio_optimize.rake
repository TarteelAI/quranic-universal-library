namespace :audio_optimize do
  task rename_files: :environment do
    base_path = "/Volumes/Data/qul-segments/audio/65/mp3"

    Dir.foreach(base_path) do |filename|
      next if filename == '.' || filename == '..'
      num = filename[/\d+/]

      new_filename = num.to_s.rjust(3, '0') + '.mp3'
      old_path = File.join(base_path, filename)
      new_path = File.join(base_path, new_filename)

      File.rename(old_path, new_path)
    end
  end

  task optimize_mp3: :environment do
    require 'open3'
    reciter_name = "Maher al-Muaiqly"
    base_path = "/Volumes/Data/qul-segments/audio/65"
    mp3_path = "#{base_path}/mp3"
    optimized_path = "#{base_path}/optimized"
    wav_path = "#{base_path}/wav"
    opus_path = "#{base_path}/opus"

    require "json"
    require "open3"

    require "json"
    require "open3"

    def encode_to_wav(mp3_path, wav_path, normalize: false)
      if File.exist?(wav_path)
        puts "#{wav_path} already exists"
        return
      end

      puts "Encoding #{mp3_path} to #{wav_path} (normalize: #{normalize.inspect})"

      case normalize
      when false
        system("ffmpeg", "-i", mp3_path, "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", wav_path)

      when :copy
        # Copy left channel only (avoid -3dB drop)
        system("ffmpeg", "-i", mp3_path, "-map_channel", "0.0.0", "-ar", "16000", "-c:a", "pcm_s16le", wav_path)

      when :gain
        # Downmix stereo → mono but boost by +3dB to compensate
        system("ffmpeg", "-i", mp3_path, "-ac", "1", "-ar", "16000",
               "-af", "volume=3dB", "-c:a", "pcm_s16le", wav_path)
      else
        raise ArgumentError, "Unsupported normalize mode: #{normalize.inspect}"
      end
    end

    def encode_to_opus(input_file, output_file, meta_data = {})
      metadata_flags = meta_data.flat_map do |key, value|
        ['-metadata', "#{key}=#{value}"]
      end

      # Opus encoding options
      audio_opts = [
        '-c:a', 'libopus',
        '-b:a', '64k',        # Good balance for speech (try 64k–96k)
        '-vbr', 'on',         # Enable variable bitrate (higher quality for same size)
        '-compression_level', '10' # Max compression
      ]

      command = [
        'ffmpeg',
        '-i', input_file,
        *audio_opts,
        '-vn',                # no video
        '-map_metadata', '-1', # drop existing metadata
        '-map_chapters', '-1',
        *metadata_flags,
        output_file
      ]

      puts "Running: #{command.join(' ')}"
      system(*command)
    end

    def optimize_mp3(file, output_file, meta_data, encoding: :cbr)
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
        'ffmpeg', '-y',
        '-i', file,
        '-c:a', 'libmp3lame',
        '-id3v2_version', '3',
        '-write_xing', '1',
        *audio_opts,
        '-vn',
        *metadata_flags,
        output_file
      ]

      system(*command)
    end

    def reencode_via_wav(input_file, output_file, meta_data = {}, encoding: :cbr)
      temp_wav = "#{File.dirname(output_file)}/#{File.basename(output_file, '.*')}.tmp.wav"

      # Step 1: Decode to WAV (keep original sample rate and channels)
      decode_cmd = [
        'ffmpeg',
        '-i', input_file,
        '-acodec', 'pcm_s16le', # 16-bit PCM
        temp_wav
      ]
      system(*decode_cmd)

      # Step 2: Re-encode WAV to MP3
      metadata_flags = meta_data.flat_map { |k, v| ['-metadata', "#{k}=#{v}"] }

      audio_opts = case encoding
                   when :vbr
                     ['-q:a', '5'] # ~150 kbps VBR
                   when :cbr
                     ['-b:a', '128k']
                   else
                     raise ArgumentError, "Unsupported encoding: #{encoding}"
                   end

      encode_cmd = [
        'ffmpeg',
        '-i', temp_wav,
        '-c:a', 'libmp3lame',
        *audio_opts,
        '-vn',
        '-map_metadata', '-1',
        '-map_chapters', '-1',
        *metadata_flags,
        output_file
      ]
      system(*encode_cmd)

      # Step 3: Clean up temp WAV
      File.delete(temp_wav) if File.exist?(temp_wav)
    end

    FileUtils.mkdir_p(optimized_path)
    FileUtils.mkdir_p(wav_path)
    FileUtils.mkdir_p(opus_path)

    (1..114).each do |num|
      chapter = Chapter.find(num)

      file_path = num.to_s.rjust(3, '0')
      file = "#{mp3_path}/#{file_path}.mp3"
      optimized = "#{optimized_path}/#{file_path}.mp3"
      wav = "#{wav_path}/#{file_path}.wav"
      opus = "#{opus_path}/#{file_path}.opus"

      if !File.exist?(optimized)
        puts "Processing Surah #{num} - #{file_path}.mp3"

        meta_data = {
          title: "Surah #{chapter.name_simple}",
          artist: reciter_name,
          album: 'Quran',
          genre: 'Quran',
          track: "#{chapter.id}/114",
          comment: 'https://qul.tarteel.ai'
        }

        success = reencode_via_wav(
          file,
          optimized,
          meta_data,
          encoding: :cbr
        )

        if success
          encode_to_wav(file, wav, normalize: :copy)
          encode_to_opus(file, opus)
        else
          puts "ffmpeg failed for Surah #{chapter.id}"
        end
      end
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
