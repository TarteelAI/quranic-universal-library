# frozen_string_literal: true
module Audio
  class GenerateAudioWavManifest
    MAX_DURATION_MS = 1.hour.in_milliseconds # 1 hour in milliseconds
    MIN_PART_DURATION_MS = 20.minutes.in_milliseconds # 20 minutes in milliseconds

    def initialize(audio_file)
      @audio_file = audio_file
      @duration_ms = audio_file.duration_ms.to_i
    end

    def run
      return [] unless should_divide?

      parts = calculate_parts
      save_parts_metadata(parts)
      parts
    end

    private

    attr_reader :audio_file, :duration_ms

    def should_divide?
      duration_ms > MAX_DURATION_MS
    end

    def calculate_parts
      num_parts = (duration_ms.to_f / MAX_DURATION_MS).ceil

      # Ensure each part is at least MIN_PART_DURATION_MS
      if duration_ms / num_parts < MIN_PART_DURATION_MS
        num_parts = (duration_ms.to_f / MIN_PART_DURATION_MS).floor
      end

      parts = []
      part_duration = duration_ms / num_parts

      num_parts.times do |index|
        start_time = index * part_duration
        end_time = [(index + 1) * part_duration, duration_ms].min

        start_ayah = find_ayah_for_timestamp(start_time)
        end_ayah = find_ayah_for_timestamp(end_time)

        parts << {
          part: index + 1,
          start_time: start_time,
          end_time: end_time,
          duration: end_time - start_time,
          start_ayah: start_ayah,
          end_ayah: end_ayah,
          url: generate_wav_file_name(index + 1)
        }
      end

      parts
    end

    def find_ayah_for_timestamp(timestamp_ms)
      Audio::Segment
        .where(
          audio_recitation_id: audio_file.audio_recitation_id
        )
        .where('timestamp_from <= ? AND timestamp_to >= ?', timestamp_ms, timestamp_ms)
        .first
    end

    def generate_wav_file_name(part_number)
      # This assumes the wav files are stored with a naming convention like:
      # original_file_part_1.wav, original_file_part_2.wav, etc.
      base_url = audio_file.audio_url
      file_extension = File.extname(base_url)
      base_name = File.basename(base_url, file_extension)

      "#{File.dirname(base_url)}/#{base_name}_part_#{part_number}.wav"
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
