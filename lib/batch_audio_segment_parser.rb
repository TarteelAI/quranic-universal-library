require 'find'
require 'fileutils'

=begin
# Basic workflow
p = BatchAudioSegmentParser.new(data_directory: "tools/segments/data/vs_logs", reset_db: false)

p.validate_log_files
p.remove_duplicate_files
p.group_files_by_reciter
p.process_all_files

1.upto(114) do |i|
  p.process_reciter(reciter: 1, surah: 2)
end

p.cleanup_duplicate_failures
p.seed_reciters
=end

class BatchAudioSegmentParser
  attr_accessor :files_with_issues,
                :data_directory
  MIN_GAP_BETWEEN_AYAHS = 80 # milliseconds - minimum gap to maintain between ayahs

  def initialize(data_directory:, reset_db: true)
    @data_directory = data_directory
    setup_db(reset_db: reset_db)
    @files_with_issues = []
  end

  def process_all_files
    files = filter_segments_files

    files.each_with_index do |file_path, index|
      puts "Processing file #{index + 1}/#{files.length}: #{file_path}"
      process_file(file_path)
    end

    after_processing_summary
  end

  def validate_log_files
    seen = Hash.new { |h, k| h[k] = [] }
    files = filter_segments_files
    files_to_remove = []

    files.each do |file_path|
      folder = File.dirname(file_path)
      filename = File.basename(folder)

      if filename =~ /^(\d{3})(\d{3})(dd|ff)-/
        reciter_id, surah_number = parse_reciter_and_surah_id(filename)
        key = "#{reciter_id}-#{surah_number}"

        if File.zero?(file_path) || File.read(file_path).strip.empty?
          puts "Empty file #{file_path}"
          files_to_remove << file_path
          next
        end

        seen[key] << file_path
      else
        puts "Invalid format: #{file_path}"
      end
    end

    puts "Finding duplicate files"
    seen.each do |key, files|
      if files.size > 1
        puts "Reciter/Surah #{key} has duplicates:"

        files_with_sizes = files.map do |path|
          size_bytes = File.size(path)
          size_kb = (size_bytes.to_f / 1024).round(2)
          data = Oj.load(File.read(path)) rescue []
          positions = data.select { |entry| entry['type'] == 'POSITION' }

          {
            path: path,
            size_bytes: size_bytes,
            size_kb: size_kb,
            positions: positions.size
          }
        end

        files_with_sizes = files_with_sizes.sort_by { |file_info| [-file_info[:positions], -file_info[:size_bytes]] }

        files_with_sizes.each_with_index do |file_info, index|
          puts "  #{file_info[:path]} - #{file_info[:size_kb]} KB"

          if file_info[:size_kb].zero?
            files_to_remove << file_info[:path]
          elsif index > 0
            puts "Duplicate file: #{file_info[:path]}"
            files_to_remove << file_info[:path]
          end
        end
      end
    end

    "Validation complete. Check the output for any issues."
    files_to_remove
  end

  def remove_duplicate_files
    files = validate_log_files
    return if files.empty?
    puts "Removing #{files.length} duplicate files and their folders"
    FileUtils.mkdir_p("#{@data_directory.gsub('vs_logs', '')}/duplicate_files")

    files.each do |file_path|
      folder = File.dirname(file_path)
      log_file_name = "#{@data_directory.gsub('vs_logs', '')}logs/#{folder.split('/').last}.log"

      FileUtils.mv(folder, "#{@data_directory.gsub('vs_logs', '')}/duplicate_files")

      if File.exist?(log_file_name)
        FileUtils.mv(log_file_name, "#{@data_directory.gsub('vs_logs', '')}/duplicate_files")
      end
    end
  end

  def update_last_ayah_with_audio_duration(reciter:, surah:)
    audio_file_path = "#{@data_directory.gsub('vs_logs', 'audio')}/#{reciter}/wav/#{format('%03d', surah)}.wav"
    duration = calculate_audio_file_duration(audio_file_path)

    if duration
      last_ayah_boundary = Segments::AyahBoundary.where(
        reciter_id: reciter,
        surah_number: surah
      ).order(ayah_number: :desc).first

      last_ayah_boundary.update_columns(
        corrected_end_time: [duration, last_ayah_boundary.corrected_end_time.to_i].max
      )
    else
      raise "Could not determine audio duration for file: #{audio_file_path}"
    end
  end

  # Adjust Ayah boundaries using silence data calculated using
  # relative volume levels around the boundaries(see find_boundary_silences.py for more info)
  def refine_boundaries_with_detected_silences(reciter:, surah:, silences_file:)
    unless File.exist?(silences_file)
      puts "Silences file not found: #{silences_file}"
      return
    end

    boundary_silences = Oj.load(File.read(silences_file))
    boundary_silences_map = {}
    boundary_silences.each do |silence|
      boundary_silences_map[silence['ayah']] = silence
    end

    adjustment_results = {}

    ayah_boundaries = Segments::AyahBoundary
                        .where(reciter_id: reciter, surah_number: surah)
                        .order('ayah_number asc')

    return if ayah_boundaries.empty?

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

    update_last_ayah_with_audio_duration(reciter: reciter, surah: surah)
    adjustment_results[ayah_boundaries.last.ayah_number][:adjustment_notes] << "Last ayah end time set to audio duration"

    # fix_boundary_overlaps(ayah_boundaries)
    ayah_boundaries.each(&:reload)

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

    adjustment_results.values
  end

  # Export ayah boundaries to JSON format for use with Python silence detection tools
  # Exports both original and corrected (final) timings
  def export_ayah_boundaries(reciter:, surah:, output_dir:)
    FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

    ayah_boundaries = Segments::AyahBoundary
                        .where(reciter_id: reciter, surah_number: surah)
                        .order('ayah_number asc')

    if ayah_boundaries.empty?
      puts "No boundaries found for Reciter #{reciter}, Surah #{surah}"
      return
    end

    boundaries_data = ayah_boundaries.map do |ayah|
      {
        ayah: ayah.ayah_number,
        start_time: ayah.start_time,
        end_time: ayah.end_time
      }
    end

    output_file = "#{output_dir}/#{surah}.json"
    File.open(output_file, "w") do |file|
      file.puts Oj.dump(boundaries_data, mode: :compat)
    end

    output_file
  end

  def seed_reciters
    segmented_recitations.each do |recitation|
      chapters = Segments::Position.where(reciter_id: recitation.id).pluck(:surah_number).uniq

      Segments::Reciter.where(id: recitation.id).first_or_create(
        name: recitation.humanize,
        segmented_chapters: chapters.join(',')
      )
    end
  end

  def cleanup_duplicate_failures
    duplicates = Segments::Failure
                   .where.not(expected_transcript: ['', nil])
                   .group(:expected_transcript, :surah_number, :ayah_number, :reciter_id)
                   .having("COUNT(*) > 5")
                   .count

    duplicates.each_key do |(expected_transcript, surah_number, ayah_number, reciter_id)|
      ids = Segments::Failure.where(
        expected_transcript: expected_transcript,
        surah_number: surah_number,
        ayah_number: ayah_number,
        reciter_id: reciter_id
      ).order(:id).pluck(:id)

      Segments::Failure.where(id: ids.drop(1)).delete_all
    end
  end

  def process_reciter(reciter:, surah: nil)
    puts "Processing files for reciter ID: #{reciter}"
    files = filter_segments_files(reciter, surah)

    files.each do |file_path|
      process_file(file_path)
    end
    after_processing_summary
  end

  def group_files_by_reciter
    files = filter_segments_files

    # Group files by reciter ID
    files_by_reciter = files.group_by do |file_path|
      folder_name = File.basename(File.dirname(file_path))
      # Extract reciter ID from folder name (first 3 digits)
      folder_name[0..2].to_i
    end

    puts "Found files for #{files_by_reciter.keys.size} reciters"

    files_by_reciter.each do |reciter_id, reciter_files|
      puts "Processing reciter ID: #{reciter_id} with #{reciter_files.size} files"

      reciter_folder = File.join(@data_directory, reciter_id.to_s)
      FileUtils.mkdir_p(reciter_folder) unless Dir.exist?(reciter_folder)

      reciter_files.each do |file_path|
        source_folder = File.dirname(file_path)
        folder_name = File.basename(source_folder)
        destination_folder = File.join(reciter_folder, folder_name)

        next if source_folder == destination_folder

        begin
          if Dir.exist?(destination_folder)
            puts "  Destination folder already exists: #{destination_folder}, skipping..."
          else
            FileUtils.mv(source_folder, destination_folder)
            puts "  Moved: #{folder_name} -> #{reciter_folder}/"
          end
        rescue => e
          puts "  Error moving #{source_folder}: #{e.message}"
        end
      end

      log_directory = @data_directory.gsub('vs_logs', 'logs')
      if Dir.exist?(log_directory)
        reciter_log_folder = File.join(log_directory, reciter_id.to_s)
        FileUtils.mkdir_p(reciter_log_folder) unless Dir.exist?(reciter_log_folder)

        reciter_files.each do |file_path|
          folder_name = File.basename(File.dirname(file_path))
          log_file = File.join(log_directory, "#{folder_name}.log")

          if File.exist?(log_file)
            destination_log = File.join(reciter_log_folder, "#{folder_name}.log")

            unless File.exist?(destination_log)
              begin
                FileUtils.mv(log_file, destination_log)
                puts "  Moved log: #{folder_name}.log -> #{reciter_log_folder}/"
              rescue => e
                puts "  Error moving log file #{log_file}: #{e.message}"
              end
            end
          end
        end
      end
    end

    puts "Grouping complete!"
  end

  def segmented_recitations
    return @recitations if @recitations.present?

    files = filter_segments_files
    recitation_ids = []

    files.select do |file_path|
      folder_name = File.basename(File.dirname(file_path))
      recitation_ids << folder_name[0..2].to_i
    end

    @recitations = Audio::Recitation.where(id: recitation_ids.uniq)
  end

  protected

  def calculate_audio_file_duration(audio_file_path)
    # Use ffprobe to get duration in seconds with high precision
    command = "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 \"#{audio_file_path}\""
    duration_seconds = `#{command}`.strip.to_f

    if duration_seconds > 0
      (duration_seconds * 1000).round
    end
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

  def after_processing_summary
    puts "Batch processing completed"

    if files_with_issues.size > 0
      puts "Following files has issues:"
      puts files_with_issues.join("\n")
    end
  end

  def merge_consecutive_duplicates_positions(positions)
    merged = []

    positions.each do |pos|
      if merged.any? &&
        merged.last[:ayah] == pos[:ayah] &&
        merged.last[:word] == pos[:word]

        # Merge with the last one
        merged.last[:end_time] = [merged.last[:end_time], pos[:end_time]].max
        merged.last[:start_time] = [merged.last[:start_time], pos[:start_time]].min
        merged.last[:text] = "#{merged.last[:text]} #{pos[:text]}"
        merged.last[:failure_data].merge!(pos[:failure_data]) # keep any failure_data
      else
        merged << pos.dup
      end
    end

    merged
  end

  def filter_segments_files(reciter_id = nil, surah_id = nil)
    files = []
    puts "Scanning directory: #{@data_directory}"

    Find.find(@data_directory) do |path|
      if File.basename(path) == "time-machine.json"
        files << path
      end
    end

    if reciter_id.present?
      files = files.select do |file_path|
        folder_name = File.basename(File.dirname(file_path))
        matched = folder_name[0..2].to_i == reciter_id

        if surah_id
          matched && folder_name[3..5].to_i == surah_id
        else
          matched
        end
      end
    end

    puts "Found #{files.length} files"
    files
  end

  def process_file(file_path)
    ActiveRecord::Base.logger = nil

    begin
      parser = AudioSegmentParser.new(file_path)
      puts "Reciter ID: #{parser.reciter_id}, Surah: #{parser.surah_number}"

      parser.run

      puts "Reciter ID: #{parser.reciter_id}, Surah: #{parser.surah_number} - Parsed #{parser.positions.count} segments"
      puts "Segments Stats: #{parser.stats}"
      puts "Fixing missing positions..."
      parser.fix_missing_positions
      puts "#{parser.positions.count} segments after fixing the missing positions"

      Segments::Position
        .where(
          surah_number: parser.surah_number,
          reciter_id: parser.reciter_id
        ).delete_all

      Segments::Failure
        .where(
          surah_number: parser.surah_number,
          reciter_id: parser.reciter_id
        ).delete_all

      Segments::AyahBoundary.where(
        surah_number: parser.surah_number,
        reciter_id: parser.reciter_id
      ).delete_all

      if parser.positions.any?
        import_segments(
          parser.positions,
          parser.failures,
          parser.reciter_id
        )
      else
        puts "No segments found, skipping import"
        filter_segments_files << file_path
      end
    rescue => e
      files_with_issues << file_path
      puts "Error processing file: #{e.message}"
      puts "Backtrace: #{e.backtrace.first(3).join("\n    ")}"
    end
  end

  def import_segments(positions, failures, reciter_id)
    positions = merge_consecutive_duplicates_positions(positions)
    positions = adjust_positions_corrected_times(positions)

    debug_ayah_segments_stats(positions, reciter_id)

    positions_data = []

    positions.each_with_index do |pos, index|
      positions_data << {
        surah_number: pos[:surah],
        ayah_number: pos[:ayah],
        word_number: pos[:word],
        word_key: generate_word_key(pos[:surah], pos[:ayah], pos[:word]),
        reciter_id: reciter_id,
        start_time: pos[:start_time],
        end_time: pos[:end_time],
        corrected_start_time: pos[:corrected_start_time],
        corrected_end_time: pos[:corrected_end_time]
      }

      if index > 0 && index % 5000 == 0
        bulk_insert_positions(positions_data)
        positions_data = []
      end
    end

    if positions_data.any?
      bulk_insert_positions(positions_data)
    end

    failures_data = failures.map do |failure|
      {
        reciter_id: reciter_id,
        surah_number: failure[:surah_number],
        ayah_number: failure[:ayah_number],
        word_number: failure[:word_number],
        word_key: generate_word_key(failure[:surah_number], failure[:ayah_number], failure[:word_number]),
        text: failure[:text],
        failure_type: failure[:failure_type],
        received_transcript: failure[:received_transcript],
        expected_transcript: failure[:expected_transcript],
        start_time: failure[:start_time],
        end_time: failure[:end_time],
        mistake_positions: failure[:mistake_positions] || '',
        corrected: failure[:corrected] || false,
        corrected_ayah_number: failure[:corrected_ayah_number],
        corrected_word_number: failure[:corrected_word_number],
        corrected_start_time: failure[:corrected_start_time],
        corrected_end_time: failure[:corrected_end_time]
      }
    end

    if failures_data.any?
      bulk_insert_failures(failures_data)
    end

    create_ayah_boundaries(reciter_id, positions)
    create_detection_data(reciter_id, positions, failures)
  end

  private

  # Validate and fix any overlaps between ayah boundaries
  # Ensures corrected_end_time <= next ayah's corrected_start_time
  def fix_boundary_overlaps(ayah_boundaries)
    return if ayah_boundaries.length < 2
    overlaps_fixed = 0

    ayah_boundaries.each_with_index do |ayah, index|
      next if index >= ayah_boundaries.length - 1 # Skip last ayah

      next_ayah = ayah_boundaries[index + 1]
      # Check for overlap (>= because touching boundaries with 0 gap is also an issue)

      if ayah.corrected_end_time >= next_ayah.corrected_start_time
        overlap = ayah.corrected_end_time - next_ayah.corrected_start_time

        puts "⚠️  Overlap detected: Ayah #{ayah.ayah_number} end (#{ayah.corrected_end_time}ms) >= Ayah #{next_ayah.ayah_number} start (#{next_ayah.corrected_start_time}ms)"
        puts "    Overlap/Touch: #{overlap}ms"

        # Fix: Set current ayah end to next ayah start - MIN_GAP_BETWEEN_AYAHS
        # new_end_time = next_ayah.corrected_start_time - MIN_GAP_BETWEEN_AYAHS
        new_end_time = next_ayah.corrected_start_time - [MIN_GAP_BETWEEN_AYAHS, overlap].max
        # Ensure we don't reduce end time below original
        # new_end_time = [new_end_time, ayah.end_time].max
        puts "    Fixing: Setting Ayah #{ayah.ayah_number} end to #{new_end_time}ms (gap: #{next_ayah.corrected_start_time - new_end_time}ms)"

        ayah.update_column(:corrected_end_time, new_end_time)
        overlaps_fixed += 1
      end

      # Also check for minimum gap
      gap = next_ayah.corrected_start_time - ayah.corrected_end_time
      if gap < MIN_GAP_BETWEEN_AYAHS && gap >= 0
        puts "⚠️  Small gap detected: #{gap}ms between Ayah #{ayah.ayah_number} and #{next_ayah.ayah_number}"
        puts "    Adjusting to maintain #{MIN_GAP_BETWEEN_AYAHS}ms minimum gap"

        # Adjust current ayah end to create minimum gap
        # new_end_time = next_ayah.corrected_start_time - MIN_GAP_BETWEEN_AYAHS
        # new_end_time = [new_end_time, ayah.end_time].max

        # ayah.update_column(:corrected_end_time, new_end_time)
        overlaps_fixed += 1
      end
    end

    if overlaps_fixed > 0
      puts "\n✓ Fixed #{overlaps_fixed} overlap(s) or gap(s)"
    end
  end

  def parse_reciter_and_surah_id(filename)
    reciter_id = filename[0..2].to_i
    surah_number = filename[3..5].to_i

    [reciter_id, surah_number]
  end

  def debug_ayah_segments_stats(positions, reciter_id)
    chapter_id = positions[0][:surah]

    review_ayahs = []
    Verse.where(chapter_id: chapter_id).find_each do |verse|
      ayah_positions = positions.select { |pos| pos[:ayah] == verse.verse_number }
      expected_word_count = verse.words_count
      actual_word_count = ayah_positions.map { |pos| pos[:word] }.uniq.count

      if expected_word_count != actual_word_count
        review_ayahs << {
          surah_number: chapter_id,
          reciter_id: reciter_id,
          verse_id: verse.id,
          ayah_number: verse.verse_number,
          review_type: 'missing_segments',
          comment: "Expected #{expected_word_count} segments, Found #{actual_word_count} segments"
        }
        puts "Mismatch in Surah #{chapter_id}, Ayah #{verse.verse_number}: Expected #{expected_word_count} words, Found #{actual_word_count} words"
      end

      if expected_word_count != ayah_positions.map { |pos| pos[:word] }.count
        review_ayahs << {
          surah_number: chapter_id,
          reciter_id: reciter_id,
          verse_id: verse.id,
          ayah_number: verse.verse_number,
          review_type: 'repetition',
          comment: "Duplicate words detected in ayah #{verse.verse_number}, maybe this ayah has repeated segments?"
        }
        puts "Duplicate words detected in Surah #{chapter_id}, Ayah #{verse.verse_number}. Maybe repeated words?"
      end

      auto_fixed_missed_positions = ayah_positions.select do |pos|
        data = pos[:failure_data] || {}
        data[:type] == 'missing_word'
      end

      if auto_fixed_missed_positions.present?
        auto_fixed_missed_positions = auto_fixed_missed_positions.group_by { |pos| [pos[:surah], pos[:ayah]] }
        auto_fixed_missed_positions.each do |(surah, ayah), fixed_ayah_positions|
          words_ids = fixed_ayah_positions.map do |a|
            a[:word]
          end

          review_ayahs << {
            surah_number: chapter_id,
            reciter_id: reciter_id,
            verse_id: verse.id,
            ayah_number: verse.verse_number,
            review_type: 'auto_fixed',
            comment: "Auto fixed the missing words(#{words_ids.uniq.join(', ')})"
          }
        end
      end
    end

    if review_ayahs.present?
      Segments::ReviewAyah.upsert_all(review_ayahs)
    end
  end

  def adjust_positions_corrected_times(positions)
    end_time_offset = 50 # milliseconds
    positions_by_ayah = positions.group_by { |pos| [pos[:surah], pos[:ayah]] }

    corrected_positions = []

    positions_by_ayah.each do |(surah, ayah), ayah_positions|
      sorted_positions = ayah_positions.sort_by { |pos| pos[:start_time] }

      sorted_positions.each_with_index do |pos, index|
        corrected_pos = pos.dup

        if index == 0
          # First word in ayah
          if pos[:ayah] == 1 && pos[:word] == 1
            corrected_pos[:corrected_start_time] = 0
          else
            corrected_pos[:corrected_start_time] = pos[:start_time]
          end

          corrected_pos[:corrected_end_time] = pos[:end_time]
        else
          previous_pos = sorted_positions[index - 1]
          gap = pos[:start_time] - previous_pos[:end_time]

          if gap > end_time_offset
            corrected_positions.last[:corrected_end_time] = [
              pos[:start_time] - end_time_offset,
              corrected_positions.last[:end_time]
            ].max

            corrected_pos[:corrected_start_time] = pos[:start_time]
          else
            corrected_pos[:corrected_start_time] = pos[:start_time]
          end

          corrected_pos[:corrected_end_time] = pos[:end_time]
        end

        corrected_positions << corrected_pos
      end
    end

    corrected_positions
  end

  def bulk_insert_positions(positions_data)
    return if positions_data.empty?

    Segments::Position.insert_all(positions_data)
  end

  def bulk_insert_failures(failures_data)
    return if failures_data.empty?

    Segments::Failure.insert_all(failures_data)
  end

  def create_ayah_boundaries(reciter_id, positions)
    ayah_groups = positions.group_by { |pos| [pos[:surah], pos[:ayah]] }

    boundaries_data = ayah_groups.map do |(surah, ayah), ayah_positions|
      grouped_positions = ayah_positions.group_by { |p| p[:word] }
      first_word = grouped_positions.keys.min
      last_word = grouped_positions.keys.max
      start_time = grouped_positions[first_word].map { |pos| pos[:start_time] }.min
      end_time = grouped_positions[last_word].map { |pos| pos[:end_time] }.max

      {
        surah_number: surah,
        ayah_number: ayah,
        verse_id: Verse.find_by_verse_key("#{surah}:#{ayah}")&.id,
        start_time: start_time,
        end_time: end_time,
        reciter_id: reciter_id
      }
    end

    if boundaries_data.any?
      bulk_insert_ayah_boundaries(boundaries_data)
    end
  end

  def bulk_insert_ayah_boundaries(boundaries_data)
    return if boundaries_data.empty?

    Segments::AyahBoundary.insert_all(boundaries_data)
  end

  def create_detection_data(reciter_id, positions, failures)
    positions_by_ayah = positions.group_by { |pos| [pos[:surah], pos[:ayah]] }
    failures_by_ayah = failures.group_by { |failure| [failure[:surah_number], failure[:ayah_number]] }

    detection_data = []

    positions_by_ayah.each do |(surah, ayah), ayah_positions|
      position_count = ayah_positions.count

      ayah_failures = failures_by_ayah[[surah, ayah]] || []
      failure_count = ayah_failures.count

      if position_count > 0
        detection_data << {
          surah_number: surah,
          ayah_number: ayah,
          reciter_id: reciter_id,
          detection_type: 'POSITION',
          count: position_count
        }
      end

      if failure_count > 0
        detection_data << {
          surah_number: surah,
          ayah_number: ayah,
          reciter_id: reciter_id,
          detection_type: 'FAILURE',
          count: failure_count
        }
      end
    end

    if detection_data.any?
      bulk_insert_detections(detection_data)
    end
  end

  def bulk_insert_detections(detection_data)
    return if detection_data.empty?

    Segments::Detection.insert_all(detection_data)
  end

  def generate_word_key(surah_number, ayah_number, word_number)
    "#{surah_number}:#{ayah_number}:#{word_number}"
  end

  def setup_db(reset_db:)
    db_file = "#{@data_directory.gsub('/vs_logs', '')}/segments_database.db"
    FileUtils.rm(db_file) if File.exist?(db_file) && reset_db

    Segments::Base.establish_connection(
      adapter: 'sqlite3',
      database: db_file
    )

    connection = Segments::Base.connection
    return if connection.table_exists?('segments_reciters')

    connection.create_table :segments_reciters do |t|
      t.string :name
      t.string :segmented_chapters
      t.text :audio_urls
    end

    connection.create_table :segments_review_ayahs do |t|
      t.integer :surah_number
      t.integer :ayah_number
      t.integer :verse_id
      t.integer :reciter_id
      t.string :comment
      t.string :review_type
    end

    connection.create_table :segments_failures do |t|
      t.integer :surah_number
      t.integer :ayah_number
      t.integer :word_number
      t.string :word_key
      t.string :text
      t.integer :reciter_id
      t.string :failure_type
      t.string :received_transcript
      t.string :expected_transcript
      t.integer :start_time
      t.integer :end_time
      t.string :mistake_positions, default: ''

      t.boolean :corrected, default: false
      t.integer :corrected_ayah_number
      t.integer :corrected_word_number
      t.integer :corrected_start_time
      t.integer :corrected_end_time
    end

    connection.create_table :segments_positions do |t|
      t.integer :surah_number
      t.integer :ayah_number
      t.integer :word_number
      t.string :word_key
      t.integer :reciter_id
      t.integer :start_time
      t.integer :end_time
      t.integer :corrected_start_time
      t.integer :corrected_end_time
    end

    connection.create_table :segments_detections do |t|
      t.integer :surah_number
      t.integer :ayah_number
      t.integer :reciter_id
      t.string :detection_type
      t.integer :count
    end

    connection.create_table :segments_logs do |t|
      t.integer :surah_number
      t.integer :reciter_id
      t.integer :timestamp
      t.string :log
    end

    connection.create_table :segments_ayah_boundaries do |t|
      t.integer :surah_number
      t.integer :ayah_number
      t.integer :reciter_id
      t.integer :verse_id

      t.integer :start_time
      t.integer :end_time

      t.integer :gap_before_start_time
      t.integer :gap_before_end_time

      t.integer :gap_after_start_time
      t.integer :gap_after_end_time

      t.integer :corrected_start_time
      t.integer :corrected_end_time
    end
  end
end