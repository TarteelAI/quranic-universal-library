namespace :audio do
  task optimize_mp3: :environment do
    # Check if mp3 is CBR or VBR
    # ffprobe -hide_banner -i 2.mp3

    # Finished 65,
    # Pending: 2, 3, 4, 5, 7, 8, 9, 12, 65, 164, 168, 171, 174, 179
    # In progress: 1, 2

    require 'open3'
    reciter_name = "Khalifah Taniji - Murattal"
    base_path = "data/audio/161"
    original_mp3_path = "#{base_path}/original"
    optimized_mp3_path = "#{base_path}/mp3"
    wav_path = "#{base_path}/wav"
    opus_path = "#{base_path}/opus"

    FileUtils.mkdir_p(optimized_mp3_path)
    FileUtils.mkdir_p(wav_path)
    FileUtils.mkdir_p(opus_path)

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
        '-b:a', '64k', # Good balance for speech (try 64k–96k)
        '-vbr', 'on', # Enable variable bitrate (higher quality for same size)
        '-compression_level', '10' # Max compression
      ]

      command = [
        'ffmpeg',
        '-i', input_file,
        *audio_opts,
        '-vn', # no video
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

    (1..114).each do |num|
      chapter = Chapter.find(num)

      file_path = num.to_s.rjust(3, '0')
      file = "#{original_mp3_path}/#{file_path}.mp3"
      optimized = "#{optimized_mp3_path}/#{file_path}.mp3"
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
          encode_to_wav(optimized, wav, normalize: :copy)
          encode_to_opus(optimized, opus)
        else
          puts "ffmpeg failed for Surah #{chapter.id}"
        end
      end
    end
  end

  task generate_wav_manifest: :environment do
    require 'json'
    require 'fileutils'

    # ids: 1, 2, 3, 4, 5, 7, 8, 9, 12, 65, 164, 168, 171, 174, 179

    reciter_id = 3
    manifest_file = "data/audio/wav_manifest/#{reciter_id}.json"
    manifest = JSON.parse(File.read(manifest_file))

    output_dir = "data/audio/#{reciter_id}/wav/parts"
    FileUtils.mkdir_p(output_dir)

    manifest.each do |surah_id, parts|
      input_file = "data/audio/#{reciter_id}/wav/#{surah_id.to_s.rjust(3, '0')}.wav"
      unless File.exist?(input_file)
        warn "Skipping Surah #{surah_id}, file not found: #{input_file}"
        next
      end

      parts.each do |part|
        part_num = part["part"]
        start_ms = part["start_time"]
        duration_ms = part["duration"]

        start_sec = start_ms / 1000.0
        duration_sec = duration_ms / 1000.0

        output_file = "#{output_dir}/#{surah_id}_part_#{part_num}.wav"

        cmd = [
          "ffmpeg",
          "-y",
          "-i", input_file,
          "-ss", start_sec.to_s,
          "-t", duration_sec.to_s,
          "-c", "copy",
          output_file
        ]

        puts "Splitting Surah #{surah_id} Part #{part_num} -> #{output_file}"
        system(*cmd)
      end
    end

    puts "Done!"
  end

  task rename_files: :environment do
    base_path = "data/audio/65/mp3"

    Dir.foreach(base_path) do |filename|
      next if filename == '.' || filename == '..'
      num = filename[/\d+/]

      new_filename = num.to_s.rjust(3, '0') + '.mp3'
      old_path = File.join(base_path, filename)
      new_path = File.join(base_path, new_filename)

      File.rename(old_path, new_path)
    end
  end
end
