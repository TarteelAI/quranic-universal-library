# frozen_string_literal: true

namespace :segments do
  task import_raw_boundaries: :environment do
    reciter_id = 179
    recitation = Audio::Recitation.find(reciter_id)

    # Setup db
    BatchAudioSegmentParser.new(data_directory: "tools/segments/data/vs_logs", reset_db: true)
    Segments::Reciter.where(id: recitation.id).first_or_create(name: recitation.name)

    Segments::Position.delete_all
    Segments::AyahBoundary.delete_all

    # Import raw segments
    Dir.glob("data/segments-json/#{recitation.id}/*.json").each do |file_path|
      data = Oj.load(File.read(file_path))

      data.each do |entry|
        surah_number = entry['surah']
        ayah_number = entry['ayah']
        segments = entry['segments'].map do |s|
          [s[1], s[2], s[3]]
        end

        segments.each do |segment|
          Segments::Position.create(
            reciter_id: recitation.id,
            surah_number: surah_number,
            ayah_number: ayah_number,
            word_number: segment[0],
            word_key: "#{surah_number}:#{ayah_number}:#{segment[0]}",
            start_time: segment[1],
            end_time: segment[2]
          )
        end

        Segments::AyahBoundary.create(
          reciter_id: recitation.id,
          surah_number: surah_number,
          ayah_number: ayah_number,
          verse_id: Utils::Quran.get_ayah_id_from_key("#{surah_number}:#{ayah_number}"),
          start_time: segments.first[1],
          end_time: segments.last[2]
        )
      end
    end

    # Import adjusted boundaries
    Dir.glob("tools/segments/data/result/adjusted-boundaries/#{recitation.id}/*.json").each do |file_path|
      chapter_number = File.basename(file_path, ".json").to_i
      data = Oj.load(File.read(file_path))
      data.each do |entry|
        surah_number = entry['surah']
        ayah_number = entry['ayah']
        start_time = entry['corrected_start_time']
        end_time = entry['corrected_end_time']

        boundary = Segments::AyahBoundary.find_by(
          reciter_id: reciter_id,
          surah_number: surah_number,
          ayah_number: ayah_number
        )

        if (boundary)
          boundary.update_columns(
            corrected_start_time: start_time,
            corrected_end_time: end_time
          )
        end
      end
    end
  end

  desc "Export ayah boundaries to JSON for boundary silence detection"
  task export_boundaries: :environment do
    reciter_id = ENV['RECITER']&.to_i || 1
    surah_number = ENV['SURAH']&.to_i || 1
    output_dir = ENV['OUTPUT_DIR'] || "tools/segments/data/boundaries/#{reciter_id}"

    puts "Exporting boundaries for Reciter #{reciter_id}, Surah #{surah_number} to #{output_dir}"

    parser = BatchAudioSegmentParser.new(data_directory: "tools/segments/data/vs_logs", reset_db: true)
    parser.export_ayah_boundaries(
      reciter: reciter_id,
      surah: surah_number,
      output_dir: output_dir
    )
  end

  task export_segments_boundaries: :environment do
    reciter_id = ENV['RECITER']&.to_i || 1
    surah_number = ENV['SURAH']&.to_i || 1
    output_dir = ENV['OUTPUT_DIR'] || "tools/segments/data/boundaries/#{reciter_id}"

    puts "Exporting boundaries for Reciter #{reciter_id}, Surah #{surah_number} to #{output_dir}"

    ayah_boundaries = Audio::Segment
                        .where(audio_recitation_id: reciter_id, chapter_id: surah_number)
                        .order('verse_number asc')

    if ayah_boundaries.empty?
      puts "No boundaries found for Reciter #{reciter_id}, Surah #{surah_number}"
      return
    end

    boundaries_data = ayah_boundaries.map do |ayah|
      {
        ayah: ayah.verse_number,
        start_time: ayah.timestamp_from,
        end_time: ayah.timestamp_to
      }
    end

    output_file = "#{output_dir}/#{surah_number}.json"
    File.open(output_file, "w") do |file|
      file.puts Oj.dump(boundaries_data, mode: :compat)
    end

    output_file
  end

  desc "Refine boundaries using detected silences from find_boundary_silences.py"
  task refine_with_silences: :environment do
    reciter_id = ENV['RECITER']&.to_i
    surah_number = ENV['SURAH']&.to_i
    silences_file = ENV['SILENCES_FILE']
    data_directory = 'tools/segments/data/vs_logs'

    unless File.exist?(silences_file)
      puts "Error: Silences file not found: #{silences_file}"
      exit 1
    end

    puts "Refining boundaries for Reciter #{reciter_id}, Surah #{surah_number}"
    puts "Using silences from: #{silences_file}"

    parser = BatchAudioSegmentParser.new(data_directory: data_directory, reset_db: false)
    parser.refine_boundaries_with_detected_silences(
      reciter: reciter_id,
      surah: surah_number,
      silences_file: silences_file
    )
  end

  task adjust_segment_boundaries_for_silences: :environment do
    reciter_id = ENV['RECITER']&.to_i
    surah_number = ENV['SURAH']&.to_i
    silences_file = ENV['SILENCES_FILE']
    MIN_GAP_BETWEEN_AYAHS = 80 # milliseconds - minimum gap to maintain between ayahs

    unless File.exist?(silences_file)
      puts "Error: Silences file not found: #{silences_file}"
      exit 1
    end

    puts "Refining boundaries for Reciter #{reciter_id}, Surah #{surah_number}"
    puts "Using silences from: #{silences_file}"

    if !File.exist?(silences_file)
      puts "Silences file not found: #{silences_file}"
      return
    end

    def adjust_boundary_start_time(ayah_boundaries, boundary_silences_map, adjustment_results)
      ayah_boundaries.each_with_index do |ayah_boundary, index|
        ayah_number = ayah_boundary.ayah_number
        ayah_silence_data = boundary_silences_map[ayah_number]
        next if ayah_boundary.blank?

        # Filter out overlapping silences - only use before_start and after_end
        useful_silences = ayah_silence_data['silences'].reject { |s| s['position'] == 'overlapping' }
        before_silences = useful_silences.select { |s| s['position'] == 'before_start' }

        ayah_result = {
          ayah: ayah_number,
          original_start: ayah_boundary.start_time,
          original_end: ayah_boundary.end_time,
          corrected_start_time: ayah_boundary.start_time,
          corrected_end_time: ayah_boundary.end_time,
          silence_before_used: nil,
          silence_after_used: nil,
          adjustment_notes: []
        }

        # For first ayah, always start at 0
        if index == 0
          ayah_result[:corrected_start_time] = 0
          ayah_result[:adjustment_notes] << 'First ayah: start set to 0'
        else
          # For subsequent ayahs, use silence before start if available
          if before_silences.any?
            # Find closest silence before start
            # filter { |s| s['distance_to_boundary'] > 0 }
            closest_before = before_silences.max_by { |s| s['distance_to_boundary'] }

            if closest_before
              # Set start to silence end + MIN_GAP_BETWEEN_AYAHS
              new_start = closest_before['start_time'] + [closest_before['distance_to_boundary'] / 2, closest_before['duration'] / 2].max
            end

            # Constraints:
            # 1. Don't move start later than original
            # 2. Don't move start before previous ayah's end (this would create overlap)
            can_use_silence = new_start <= ayah_boundary.start_time

            if can_use_silence
              ayah_result[:corrected_start_time] = new_start
              ayah_result[:silence_before_used] = closest_before
              ayah_result[:adjustment_notes] << "Start adjusted using silence that ends at: #{closest_before['end_time']}ms)"
            elsif new_start > ayah_boundary.start_time
              ayah_result[:adjustment_notes] << "Silence would move start too late, keeping current"
            end
          else
            ayah_result[:adjustment_notes] << 'No usable silence before start'
          end
        end

        adjustment_results[ayah_number] = ayah_result
      end

      adjustment_results
    end

    def adjust_boundary_end_time(ayah_boundaries, boundary_silences_map, adjustment_results)
      ayah_boundaries.each_with_index do |ayah_boundary, index|
        ayah_number = ayah_boundary.ayah_number
        next_ayah = ayah_boundaries[index + 1]
        next if next_ayah.blank? # last ayah

        ayah_result = adjustment_results[ayah_number]
        next_ayah_result = adjustment_results[ayah_number + 1]
        next if next_ayah_result.blank?

        ayah_silence_data = boundary_silences_map[ayah_number]
        useful_silences = ayah_silence_data['silences'].reject { |s| s['position'] == 'overlapping' }
        after_silences = useful_silences.select { |s| s['position'] == 'after_end' }

        current_end = ayah_result[:original_end]
        new_end = current_end

        # Maximum allowed end time (must leave MIN_GAP_BETWEEN_AYAHS before next ayah)
        max_allowed_end = next_ayah_result[:corrected_start_time] - MIN_GAP_BETWEEN_AYAHS

        if after_silences.any?
          # Find the silence closest to the current end time
          closest_after = after_silences.min_by { |s| s['distance_to_boundary'] }
          farthest_after = after_silences.max_by { |s| s['distance_to_boundary'] }

          distances = [
            max_allowed_end
          ]

          if closest_after
            distances << closest_after['end_time'] + MIN_GAP_BETWEEN_AYAHS
          end

          if farthest_after
            distances << farthest_after['start_time'] - MIN_GAP_BETWEEN_AYAHS
          end
          max_allowed_end = distances.min

          # Calculate 50% of the silence duration
          # silence_extension = (closest_after['duration'] * 0.5).round
          # proposed_end = current_end + silence_extension

          while new_end + 30 < max_allowed_end
            new_end += 30
          end

          if new_end > current_end
            ayah_result[:corrected_end_time] = new_end
            ayah_result[:silence_after_used] = closest_after
            ayah_result[:adjustment_notes] << "End extended by #{new_end - current_end}ms using silence (#{closest_after['duration']}ms)"
          else
            ayah_result[:adjustment_notes] << "Cannot extend end: would violate minimum gap to next ayah"
          end
        else
          # No silence - use gap duration and extend by 50%
          # Calculate gap between current end and next ayah start
          gap_duration = next_ayah_result[:corrected_start_time] - current_end

          if gap_duration > MIN_GAP_BETWEEN_AYAHS
            # We have room to extend - use 50% of available gap
            available_gap = gap_duration - MIN_GAP_BETWEEN_AYAHS
            extended_time = 0

            while new_end < max_allowed_end && extended_time < available_gap
              new_end += 30
              extended_time += 30
            end

            # gap_extension = (available_gap * 0.5).round
            # Proposed new end time
            # proposed_end = current_end + gap_extension

            # Ensure we don't exceed the maximum allowed end time
            # new_end = [proposed_end, max_allowed_end].min

            # Only extend if the new end is actually greater than current
            if new_end > current_end
              ayah_result[:corrected_end_time] = new_end
              ayah_result[:adjustment_notes] << "End extended by #{new_end - current_end}ms using gap duration (#{gap_duration}ms)"
            else
              ayah_result[:adjustment_notes] << "Gap too small to extend end time"
            end
          else
            ayah_result[:adjustment_notes] << "No silence after end, gap too small to extend"
          end
        end

        if ayah_result[:corrected_end_time] >= next_ayah_result[:corrected_start_time]
          ayah_result[:corrected_end_time] = next_ayah_result[:corrected_start_time] - MIN_GAP_BETWEEN_AYAHS
          ayah_result[:adjustment_notes] << "End time capped to maintain minimum gap"
        end

        adjustment_results[ayah_number] = ayah_result
      end
    end

    ayah_boundaries = Audio::Segment
                        .where(audio_recitation_id: reciter, chapter_id: surah)
                        .order('verse_number asc')

    boundary_silences = Oj.load(File.read(silences_file))
    boundary_silences_map = {}
    adjustment_results = {}

    boundary_silences.each do |silence|
      boundary_silences_map[silence['ayah']] = silence
    end

    adjustment_results = adjust_boundary_start_time(ayah_boundaries, boundary_silences_map, adjustment_results)
    adjust_boundary_end_time(ayah_boundaries, boundary_silences_map, adjustment_results)

    ayah_boundaries.each_with_index do |ayah_boundary, i|
      next_ayah = adjustment_results[ayah_boundary.ayah_number + 1]
      adjustment = adjustment_results[ayah_boundary.ayah_number]
      start_time = adjustment[:corrected_start_time]
      end_time = adjustment[:corrected_end_time]

      if next_ayah
        end_time = [end_time, next_ayah[:corrected_start_time] - MIN_GAP_BETWEEN_AYAHS].max
      end

      ayah_boundary.update_columns(
        corrected_start_time: start_time,
        corrected_end_time: end_time
      )
    end

    plot_data = []
    ayah_boundaries.each_with_index do |ayah_boundary, idx|
      result_data = adjustment_results[ayah_boundary.ayah_number]

      # Determine which silence was used (if any)
      silence_used = nil
      if result_data
        if result_data[:silence_before_used]
          silence_used = result_data[:silence_before_used]
        elsif result_data[:silence_after_used]
          silence_used = result_data[:silence_after_used]
        end
      end

      # Calculate gap to next ayah
      gap_to_next = nil
      if idx < ayah_boundaries.length - 1
        next_ayah = ayah_boundaries[idx + 1]
        gap_to_next = next_ayah.corrected_start_time - ayah_boundary.corrected_end_time
      end

      plot_data << {
        ayah: ayah_boundary.ayah_number,
        start_time: ayah_boundary.start_time,
        end_time: ayah_boundary.end_time,
        silence_used: silence_used,
        corrected_start_time: ayah_boundary.corrected_start_time,
        corrected_end_time: ayah_boundary.corrected_end_time,
        adjustment_method: result_data ? result_data[:adjustment_notes].join('; ') : 'refined_with_boundary_silences',
        gap_to_next: gap_to_next
      }
    end

    # Save detailed refinement results
    result_path = "tools/segments/data/result/plot_data/#{reciter}"
    FileUtils.mkdir_p(result_path) unless Dir.exist?(result_path)
    File.open("#{result_path}/#{surah}.json", "wb") do |file|
      file.puts Oj.dump(plot_data, mode: :compat)
    end

    puts "Refinement Summary:"
    adjustment_results.values.each do |r|
      start_change = r[:corrected_start_time] - r[:original_start]
      end_change = r[:corrected_end_time] - r[:original_end]

      if start_change != 0 || end_change != 0
        puts "Ayah #{r[:ayah]}:"
        puts "  Start: #{r[:current_corrected_start]}ms → #{r[:new_corrected_start]}ms (#{start_change > 0 ? '+' : ''}#{start_change}ms)" if start_change != 0
        puts "  End: #{r[:current_corrected_end]}ms → #{r[:new_corrected_end]}ms (#{end_change > 0 ? '+' : ''}#{end_change}ms)" if end_change != 0
        r[:adjustment_notes].each { |note| puts "    - #{note}" }
      end
    end

    puts "Results saved:"
    puts "Detailed: #{result_path}/#{surah}_refined.json"
    puts "Plot data: #{result_path}/#{surah}.json"
  end
end

