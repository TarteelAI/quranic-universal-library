require 'find'
require 'fileutils'

=begin
p = BatchAudioSegmentParser.new(data_directory: "/Volumes/Data/qul-segments/15-sept/vs_logs", reset_db: false)

p.validate_log_files
p.remove_duplicate_files

p.process_all_files

1.upto(114) do |i|
  p.process_reciter(reciter: 65, surah: 1)
end

p.segmented_recitations.each do |r|
1.upto(114) do |i|
  p.prepare_ayah_boundaries(reciter: 65, surah: 1)
end
end

p.seed_reciters
=end

class BatchAudioSegmentParser
  attr_accessor :files_with_issues,
                :data_directory

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
          { path: path, size_bytes: size_bytes, size_kb: size_kb }
        end.sort_by { |file_info| -file_info[:size_bytes] }

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

    files.each do |file_path|
      folder = File.dirname(file_path)
      log_file_name = "#{@data_directory.gsub('vs_logs', '')}logs/#{folder.split('/').last}.log"
      FileUtils.mv(folder, "#{@data_directory.gsub('vs_logs', '')}/duplicate_files")
      FileUtils.mv(log_file_name, "#{@data_directory.gsub('vs_logs', '')}/duplicate_files")
    end
  end

  def prepare_ayah_boundaries(reciter:, surah:)

    silence_file_path = "#{@data_directory.gsub('vs_logs', '')}silences/#{reciter}/#{surah}_silences.json"
    if !File.exist?(silence_file_path)
      puts "Silence file not found: #{silence_file_path}, skipping Surah #{surah} for Reciter #{reciter}"
      return
    end

    silences = Oj.load(File.read(silence_file_path))
    ayah_segments = Segments::AyahBoundary
                      .where(reciter_id: reciter, surah_number: surah)
                      .order('ayah_number asc')

    result = []
    ayah_segments.each_with_index do |ayah, index|
      ayah_data = {
        ayah: ayah.ayah_number,
        start_time: ayah.start_time,
        end_time: ayah.end_time,
        gap_start_time: nil,
        gap_end_time: nil,
        corrected_start_time: nil,
        corrected_end_time: nil
      }

      # Find all silences that end before this ayah starts
      preceding_silences = silences.select do |silence|
        (silence['end_time'] - 10) < ayah.start_time
      end

      gap_found = false
      if preceding_silences.any?
        # Get the silence that ends closest to the ayah start time
        closest_silence = preceding_silences.max_by { |silence| silence['end_time'] }

        # For non-first ayahs, ensure the gap doesn't overlap with previous ayah
        if index > 0
          previous_ayah = ayah_segments[index - 1]
          # Only use if silence starts after previous ayah ends
          if closest_silence['start_time'] >= previous_ayah.end_time
            ayah_data[:gap_start_time] = closest_silence['start_time']
            ayah_data[:gap_end_time] = closest_silence['end_time']
            gap_found = true
          end
        else
          # For first ayah, just use the closest silence before it
          ayah_data[:gap_start_time] = closest_silence['start_time']
          ayah_data[:gap_end_time] = closest_silence['end_time']
          gap_found = true
        end
      end

      # Special case for first ayah - check for silence at the very beginning
      if index == 0 && !gap_found
        initial_silence = silences.find { |silence| silence['start_time'] == 0 }
        if initial_silence && initial_silence['end_time'] < ayah.start_time
          ayah_data[:gap_start_time] = initial_silence['start_time']
          ayah_data[:gap_end_time] = initial_silence['end_time']
          gap_found = true
        end
      end

      # Set corrected times based on gap detection
      if gap_found
        ayah_data[:corrected_start_time] = ayah_data[:gap_end_time]
        ayah_data[:corrected_end_time] = ayah.end_time
      else
        ayah_data[:corrected_start_time] = ayah.start_time
        ayah_data[:corrected_end_time] = ayah.end_time
      end

      # Handle large gaps between ayahs
      if index > 0
        previous_ayah = ayah_segments[index - 1]
        gap_between_ayahs = ayah_data[:corrected_start_time] - previous_ayah.end_time

        if gap_between_ayahs > 100
          # Move current ayah start time up to 300 ms earlier
          max_adjustment = [gap_between_ayahs - 100, 300].min # Leave at least 100ms gap
          adjusted_start_time = ayah_data[:corrected_start_time] - max_adjustment

          # Ensure adjusted start time is still greater than previous ayah end time
          if adjusted_start_time > previous_ayah.end_time
            ayah_data[:corrected_start_time] = adjusted_start_time

            # Also adjust the previous ayah's end time to be much closer to current ayah start
            # Target: leave only about 300ms gap between ayahs
            target_gap = 300
            previous_ayah_end_time = adjusted_start_time - target_gap

            # Ensure previous ayah end time is not less than its original end time
            previous_ayah_end_time = [previous_ayah_end_time, previous_ayah.end_time].max
            previous_ayah.update_column(:corrected_end_time, previous_ayah_end_time)
          end
        end
      end

      # Update database with all the calculated values
      update_data = {
        gap_before_start_time: ayah_data[:gap_start_time],
        gap_before_end_time: ayah_data[:gap_end_time],
        corrected_start_time: ayah_data[:corrected_start_time],
        corrected_end_time: ayah_data[:corrected_end_time]
      }

      ayah.update_columns(update_data)

      result << ayah_data
    end

    FileUtils.mkdir_p("tools/waveform-ayah-segments/result/#{reciter}_plot_data") unless Dir.exist?("tools/waveform-ayah-segments/result/#{reciter}_plot_data")
    File.open("tools/waveform-ayah-segments/result/#{reciter}_plot_data/#{surah}.json", "wb") do |file|
      file.puts Oj.dump(result, mode: :compat)
    end
  end

  def seed_reciters
    segmented_recitations.each do |recitation|
      chapters = Segments::Position.where(reciter_id: recitation.id).pluck(:surah_number).uniq
      uri = URI("https://qul.tarteel.ai/api/v1/audio/surah_recitations/#{recitation.id}?t=#{Time.now.to_i}")
      response = Net::HTTP.get_response(uri)
      data = JSON.parse(response.body)
      audio_urls = []
      audio_files = data.dig("recitation", "audio_files")
      audio_files.each do |surah, info|
        audio_urls << info["audio_url"]
      end

      Segments::Reciter.where(id: recitation.id).first_or_create(
        name: recitation.humanize,
        audio_urls: audio_urls.join(','),
        segmented_chapters: chapters.join(',')
      )
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
    positions = calculate_corrected_times(positions)

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

  def calculate_corrected_times(positions)
    end_time_offset = 50 # milliseconds
    positions_by_ayah = positions.group_by { |pos| [pos[:surah], pos[:ayah]] }

    corrected_positions = []

    positions_by_ayah.each do |(surah, ayah), ayah_positions|
      sorted_positions = ayah_positions.sort_by { |pos| pos[:start_time] }

      sorted_positions.each_with_index do |pos, index|
        corrected_pos = pos.dup

        if index == 0
          # First word in ayah - check if it's the very first word (ayah 1, word 1)
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
      start_time = ayah_positions.map { |pos| pos[:start_time] }.min
      end_time = ayah_positions.map { |pos| pos[:end_time] }.max

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