# frozen_string_literal: true
module Audio
  class GenerateAudioWavManifest
    MAX_DURATION_MS = 1.hour.in_milliseconds # 1 hour in milliseconds
    MIN_PART_DURATION_MS = 20.minutes.in_milliseconds # 20 minutes in milliseconds

    def initialize(audio_file)
      @audio_file = audio_file
      @duration_ms = audio_file.duration_ms.to_i
    end

    def run(split_audio: false)
      puts "Generating WAV manifest for AudioFile ID: #{audio_file.id}, Duration: #{duration_ms}ms"

      parts = calculate_parts
      split_audio_files(parts) if split_audio && parts.size > 1
      save_parts_metadata(parts)
      parts
    end

    private

    attr_reader :audio_file,
                :duration_ms

    def should_divide?
      duration_ms > MAX_DURATION_MS
    end

    def calculate_parts
      num_parts = (duration_ms.to_f / MAX_DURATION_MS).ceil

      parts = []

      if num_parts > 1
        last_end_time = nil
        part_duration = duration_ms / num_parts

        num_parts.times do |index|
          start_time = last_end_time ? last_end_time + 1000 : index * part_duration
          end_time = [start_time + part_duration, duration_ms].min

          start_ayah = find_ayah_for_timestamp(start_time)
          end_ayah = find_ayah_for_timestamp(end_time)
          last_end_time = end_ayah.timestamp_to

          parts << {
            part: index + 1,
            start_time: start_ayah.timestamp_from,
            end_time: end_ayah.timestamp_to,
            duration: end_time - start_time,
            start_ayah: start_ayah.verse_key,
            end_ayah: end_ayah.verse_key,
            url: generate_wav_file_name(index + 1, num_parts),
          }
        end
      else
        chapter = audio_file.chapter

        parts << {
          part: 1,
          start_time: 0,
          end_time: duration_ms,
          duration: duration_ms,
          start_ayah: chapter.verses.first.verse_key,
          end_ayah: chapter.verses.last.verse_key,
          url: generate_wav_file_name(1, 1),
        }
      end

      parts
    end

    def find_ayah_for_timestamp(timestamp_ms)
      audio_file.audio_segments
        .where('timestamp_from <= ? AND timestamp_to >= ?', timestamp_ms, timestamp_ms)
        .first
    end

    def split_audio_files(parts)
      #TODO: Make the source file path dynamic based on the audio_file record
      source_file_path = "tmp/audio/65/wav/#{audio_file.chapter_id.to_s.rjust(3, '0')}.wav"

      unless source_file_path && File.exist?(source_file_path)
        puts "Source audio file not found: #{source_file_path}"
        return
      end
      puts "Starting audio splitting for #{parts.length} parts"

      parts.each_with_index do |part, index|
        output_path = get_output_file_path(part[:part])

        begin
          split_audio_file(source_file_path, output_path, part[:start_time], part[:end_time])

          # Verify the output file was created
          if File.exist?(output_path) && File.size(output_path) > 0
            puts "Successfully created: #{output_path} (#{File.size(output_path)} bytes)"
          else
            puts "Output file not created or empty: #{output_path}"
          end
        rescue => e
          puts "Failed to split part #{part[:part]}: #{e.message}"
          raise e
        end
      end
    end

    def split_audio_file(source_path, output_path, start_time_ms, end_time_ms)
      require 'open3'

      unless ffmpeg_available?
        raise "ffmpeg is not available. Please install ffmpeg to split audio files."
      end

      # Convert milliseconds to seconds for ffmpeg
      start_time_seconds = start_time_ms / 1000.0
      duration_seconds = (end_time_ms - start_time_ms) / 1000.0

      if duration_seconds <= 0
        puts "Invalid duration for segment: #{duration_seconds}s"
        return
      end

      FileUtils.mkdir_p(File.dirname(output_path))

      # Use ffmpeg to split the audio
      cmd = [
        'ffmpeg',
        '-i', source_path,
        '-ss', start_time_seconds.to_s,
        '-t', duration_seconds.to_s,
        '-c', 'copy', # Copy without re-encoding for speed
        '-avoid_negative_ts', 'make_zero',
        '-y', # Overwrite output file
        output_path
      ]

      stdout, stderr, status = Open3.capture3(*cmd)

      unless status.success?
        Rails.logger.error "Failed to split audio: #{stderr}"
        raise "Audio splitting failed: #{stderr}"
      end

      Rails.logger.info "Successfully split audio: #{output_path}"
    end

    def ffmpeg_available?
      require 'open3'

      begin
        stdout, stderr, status = Open3.capture3('ffmpeg', '-version')
        status.success?
      rescue => e
        Rails.logger.error "Error checking ffmpeg availability: #{e.message}"
        false
      end
    end

    def get_output_file_path(part_number)
      "tools/segments/data/audio/65/wav_parts/#{audio_file.chapter_id.to_s.rjust(3, '0')}_part_#{part_number}.wav"
    end

    def generate_wav_file_name(part_number, total_parts)
      base_url = audio_file.audio_url
      file_extension = File.extname(base_url)
      base_name = File.basename(base_url, file_extension)

      if total_parts > 1
        "#{File.dirname(base_url)}/#{base_name}_part_#{part_number}.wav"
      else
        base_url.gsub('mp3', 'wav')
      end
    end

    def save_parts_metadata(parts)
      return if parts.empty?

      data = parts.map do |part|
        {
          part: part[:part],
          path: part[:url],
          start: part[:start_ayah],
          end: part[:end_ayah],
          duration: part[:duration]
        }
      end

      audio_file.set_meta_value('wav_parts', data)
      audio_file.save
    end
  end
end
