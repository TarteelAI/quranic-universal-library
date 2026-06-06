namespace :audio do
  task optimize_mp3: :environment do
    # Check if mp3 is CBR or VBR
    # ffprobe -hide_banner -i 2.mp3

    # Finished 65,
    # Pending: 2, 3, 4, 5, 7, 8, 9, 12, 65, 164, 168, 171, 174, 179
    # In progress: 1, 2

    require 'open3'
    reciter_name = "Abdul Kabir Haidari - Murattal"
    base_path = "data/audio/180"
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

    def probe_bitrate(file_path)
      result = `ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 #{Shellwords.escape(file_path)} 2>/dev/null`.strip
      kbps = (result.to_i / 1000.0).ceil
      kbps >= 32 ? "#{kbps}k" : '64k'
    rescue StandardError
      '64k'
    end

    def reencode_via_wav(input_file, output_file, meta_data = {}, encoding: :cbr, bitrate: '128k')
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
                   when :vbr then ['-q:a', '5']
                   when :cbr then ['-b:a', bitrate]
                   else raise ArgumentError, "Unsupported encoding: #{encoding}"
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

        source_bitrate = probe_bitrate(file)
        puts "  Source bitrate: #{source_bitrate}"

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
          encoding: :cbr,
          bitrate: source_bitrate
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

  task find_suspicious_durations: :environment do
    require 'csv'

    default_ids = [179, 4, 175, 6, 13, 161, 9, 1, 2, 3, 7, 65, 164, 174]
    ids_arg = ENV['IDS'].to_s.strip
    check_ids =
      if ids_arg.empty?
        default_ids
      elsif ids_arg.casecmp('all').zero?
        Audio::Recitation.order(:id).pluck(:id)
      else
        ids_arg.split(',').map { |v| v.strip.to_i }.reject(&:zero?)
      end

    low = (ENV['LOW'] || 0.7).to_f
    high = (ENV['HIGH'] || 1.5).to_f
    min_peers = (ENV['MIN_PEERS'] || 3).to_i
    min_ayah_ms = (ENV['MIN_AYAH_MS'] || 100).to_i
    min_truncated = (ENV['MIN_TRUNCATED'] || 2).to_i

    def median_of(values)
      return nil if values.empty?
      sorted = values.sort
      n = sorted.size
      n.odd? ? sorted[n / 2].to_f : (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    end

    def without_one(values, value)
      index = values.index(value)
      return values if index.nil?
      copy = values.dup
      copy.delete_at(index)
      copy
    end

    style_names = RecitationStyle.pluck(:id, :name).to_h
    style_label = ->(sid) { sid.nil? ? 'none' : (style_names[sid] || sid.to_s) }
    to_seconds = ->(ms) { ms.nil? ? nil : (ms.to_f / 1000).round(1) }

    raw = Audio::ChapterAudioFile
            .joins(:audio_recitation)
            .where.not(duration_ms: [nil, 0])
            .pluck('audio_recitations.recitation_style_id', :chapter_id, :duration_ms)

    baseline = Hash.new { |hash, key| hash[key] = [] }
    raw.each do |style_id, chapter_id, duration_ms|
      baseline[[style_id, chapter_id]] << duration_ms
    end

    recitations = Audio::Recitation.where(id: check_ids).index_by(&:id)
    files_by_recitation = Audio::ChapterAudioFile
                            .where(audio_recitation_id: check_ids)
                            .group_by(&:audio_recitation_id)

    rows = []
    checked = 0

    check_ids.each do |rid|
      recitation = recitations[rid]
      unless recitation
        puts "Skipping #{rid}: no Audio::Recitation found"
        next
      end

      checked += 1
      style_id = recitation.recitation_style_id
      reciter_name = recitation.name
      existing = (files_by_recitation[rid] || []).index_by(&:chapter_id)

      chapter_data = {}
      1.upto(114) do |chapter_id|
        file = existing[chapter_id]
        own_duration = file&.duration_ms.to_i
        peers =
          if own_duration > 0
            without_one(baseline[[style_id, chapter_id]], own_duration)
          else
            baseline[[style_id, chapter_id]]
          end
        med = median_of(peers)
        ratio = (med && own_duration > 0) ? own_duration / med : nil
        chapter_data[chapter_id] = {
          file: file, own_duration: own_duration, peer_count: peers.size,
          median: med, ratio: ratio
        }
      end

      reliable = chapter_data.values.select { |d| d[:ratio] && d[:peer_count] >= min_peers }
      self_ratio = median_of(reliable.map { |d| d[:ratio] })

      segments_by_chapter = Audio::Segment
                              .where(audio_recitation_id: rid)
                              .pluck(:chapter_id, :verse_number, :timestamp_from, :timestamp_to)
                              .group_by(&:first)

      chapter_data.each do |chapter_id, data|
        rel = (self_ratio && self_ratio > 0 && data[:ratio]) ? (data[:ratio] / self_ratio) : nil

        dur_flag =
          if data[:file].nil?
            data[:median].nil? ? nil : 'MISSING_FILE'
          elsif data[:own_duration] <= 0
            'MISSING_DURATION'
          elsif data[:median].nil? || data[:peer_count] < min_peers || rel.nil?
            'LOW_CONFIDENCE'
          elsif rel < low
            'SHORT'
          elsif rel > high
            'LONG'
          end

        segments = (segments_by_chapter[chapter_id] || [])
                     .sort_by { |row| row[1].to_i }
        durations = segments.map { |row| [row[1].to_i, row[3].to_i - row[2].to_i] }
        collapsed = durations.count { |(_verse, dur)| dur <= min_ayah_ms }
        trailing = 0
        last_real_verse = nil
        durations.reverse_each do |(verse, dur)|
          if dur <= min_ayah_ms
            trailing += 1
          else
            last_real_verse = verse
            break
          end
        end
        truncated_after = trailing >= min_truncated ? (last_real_verse || 0) : nil
        seg_flag = truncated_after.nil? ? nil : 'TRUNCATED_SEGMENTS'

        verdict =
          if seg_flag && dur_flag == 'SHORT'
            'AUDIO_TRUNCATED'
          elsif seg_flag
            'SEGMENTS_INCOMPLETE'
          else
            dur_flag
          end

        next if verdict.nil?

        rows << {
          recitation_id: rid,
          reciter_name: reciter_name,
          style: style_label.call(style_id),
          chapter: chapter_id,
          duration_s: to_seconds.call(data[:file]&.duration_ms),
          peer_median_s: to_seconds.call(data[:median]&.round),
          ratio: data[:ratio]&.round(3),
          rel: rel&.round(3),
          peer_count: data[:peer_count],
          dur_flag: dur_flag,
          segment_count: segments.size,
          collapsed_segments: collapsed,
          truncated_after_ayah: truncated_after,
          seg_flag: seg_flag,
          verdict: verdict
        }
      end
    end

    csv_path = Rails.root.join('tmp', 'suspicious_audio_durations.csv')
    CSV.open(csv_path, 'w') do |csv|
      csv << %w[recitation_id reciter_name style chapter duration_s peer_median_s ratio rel peer_count
                dur_flag segment_count collapsed_segments truncated_after_ayah seg_flag verdict]
      rows.each do |row|
        csv << [row[:recitation_id], row[:reciter_name], row[:style], row[:chapter],
                row[:duration_s], row[:peer_median_s], row[:ratio], row[:rel], row[:peer_count],
                row[:dur_flag], row[:segment_count], row[:collapsed_segments],
                row[:truncated_after_ayah], row[:seg_flag], row[:verdict]]
      end
    end

    verdict_order = %w[AUDIO_TRUNCATED SEGMENTS_INCOMPLETE SHORT LONG MISSING_DURATION MISSING_FILE]
    verdict_order.each do |verdict|
      group = rows.select { |row| row[:verdict] == verdict }
                  .sort_by { |row| [row[:recitation_id], row[:rel] || Float::INFINITY] }
      next if group.empty?

      puts "\n## #{verdict} (#{group.size})"
      group.each do |row|
        cut = row[:truncated_after_ayah] ? " cut_after_ayah=#{row[:truncated_after_ayah]}" : ''
        puts format("  %-4d %-30s surah %3d  dur=%-8s median=%-8s rel=%-6s collapsed=%d%s",
                    row[:recitation_id], row[:reciter_name].to_s[0, 30], row[:chapter],
                    row[:duration_s].to_s, row[:peer_median_s].to_s, row[:rel].to_s,
                    row[:collapsed_segments], cut)
      end
    end

    summary = Hash.new(0)
    rows.each { |row| summary[row[:verdict]] += 1 }
    puts "\n=== Summary ==="
    puts "Recitations checked: #{checked}"
    (verdict_order + %w[LOW_CONFIDENCE]).each do |verdict|
      puts "  #{verdict}: #{summary[verdict]}"
    end
    puts "CSV written to #{csv_path}"
  end
end
