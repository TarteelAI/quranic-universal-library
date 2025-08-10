require 'sqlite3'
require 'fileutils'
=begin
a = SegmentLogsParser.new

# Validate the logs, remove duplicate etc
a.validate_log_files

# parse and fill in segments table
a.seed_segments_tables

# auto correct and export segment db for all reciter
a.prepare_recitation_dbs

# update stats of fixed segments
a.update_fixed_failures
=end

class SegmentLogsParser
  attr_reader :base_path,
              :segments_logs_path,
              :db_file

  MUSHAF_TRANSLATOR_INDEX = Oj.load(File.read("lib/data/mushaf-translator-index.json"))
  RECITER_SEGMENTS_DB = {}
  MADD_DIACRITICS = {
    "ٓ" => 6,
    "" => 4,
    "آّ" => 6,
    "ٰ" => 4
  }

  def initialize
    @base_path = "/Volumes/Data/qul-segments/aug-6"
    @segments_logs_path = "#{@base_path}/vs_logs/**/time-machine.json"
    @db_file = "#{@base_path}/segments_database.db"
  end

  def validate_log_files
    seen = Hash.new { |h, k| h[k] = [] }

    Dir.glob(segments_logs_path).each do |file_path|
      folder = File.dirname(file_path)
      filename = File.basename(folder)

      if filename =~ /^(\d{4})(\d{4})-/
        reciter_id, surah_number = parse_reciter_and_surah(filename)
        key = "#{reciter_id}-#{surah_number}"

        if File.zero?(file_path) || File.read(file_path).strip.empty?
          puts "Removing empty folder: #{folder}"
          FileUtils.rm_rf(folder)
          next
        end

        seen[key] << file_path
      else
        puts "Invalid format: #{file_path}"
      end
    end

    puts "Duplicate entries:"
    seen.each do |key, files|
      if files.size > 1
        puts "Reciter/Surah #{key} has duplicates:"
        files.each do |path|
          size_kb = (File.size(path).to_f / 1024).round(2)
          puts "  #{path} - #{size_kb} KB"
        end
      end
    end

    "Validation complete. Check the output for any issues."
  end

  def seed_segments_tables
    setup_db
    seed_raw_logs

    Dir.glob(segments_logs_path) do |file_path|
      puts "Processing #{file_path}"

      filename = File.basename(File.dirname(file_path))
      next unless filename.match?(/^\d{8}-/)
      reciter_id, surah_number = parse_reciter_and_surah(filename)

      content = File.read(file_path)
      next if content.blank?

      seed_segments(content, reciter_id, surah_number)
    end

    seed_recitations
  end

  def prepare_recitation_dbs
    Dir.glob(segments_logs_path) do |file_path|
      content = File.read(file_path)
      next if content.blank?
      data = JSON.parse(content)

      filename = File.basename(File.dirname(file_path))
      reciter_id, surah_number = parse_reciter_and_surah(filename)

      puts "Processing #{file_path}"
      export_path = "#{base_path}/results/#{reciter_id}"
      FileUtils.mkdir_p("#{export_path}/json")

      RECITER_SEGMENTS_DB[reciter_id] ||= create_recitation_segments_db(export_path)
      db = RECITER_SEGMENTS_DB[reciter_id]

      segments = process_surah_segments(data, surah_number)

      segments = auto_fix_segments_issues(segments, surah_number)

      json_data = {}

      if segments.blank?
        puts "No segments found for #{file_path}"
        next
      end

      segments.each do |segment|
        words = segment[:words]
        ayah_number = segment[:ayah]
        start_time = segment[:start_time]
        end_time = segment[:end_time]
        json_data[ayah_number] = words
        insert_segment(db, surah_number, ayah_number, start_time, end_time, words)
      end

      File.open("#{export_path}/json/#{surah_number}.json", 'w') do |f|
        f.puts json_data.to_json
      end
    end
  end

  def update_fixed_failures
    Segments::Base.establish_connection(
      adapter: 'sqlite3',
      database: db_file.to_s
    )

    segment_models = (Segments::Database.new).send(:segment_models)
    segment_models.each(&:reset_column_information)
    db_cache = {}
    base_results_path = File.join(base_path, 'results')

    Segments::Failure.update_all(
      corrected: false,
      corrected_ayah_number: nil,
      corrected_word_number: nil
    )

    seed_adjusted_segment_positions
    seed_missed_segments

    Segments::Failure.where.not(failure_type: 'MISSED_WORD').find_each do |failure|
      reciter_id = failure.reciter_id
      surah_number = failure.surah_number

      ayah_number = failure.ayah_number
      word_number = failure.word_number
      failure_text = failure.text
      expected_text = failure.expected_transcript
      failed_words = [failure.word_number].compact_blank

      if surah_number.blank? || ayah_number.blank?
        if failure.mistake_positions.present?
          surah_number, ayah_number, _word_number = failure.mistake_positions.split(',').first.split(':').map(&:to_i)

          if word_number.nil? && ayah_number && (failure_text.present? || expected_text)
            word_number = detect_word_number_from_text(surah_number, ayah_number, failure_text)
            word_number ||= detect_word_number_from_text(surah_number, ayah_number, expected_text)

            if word_number
              failed_words = [word_number]
            end

            if word_number.nil? && _word_number.present?
              failed_words = detect_merged_word_numbers(surah_number, ayah_number, _word_number, failure_text)
            end
          end
        end
      end

      next if failed_words.blank?

      db_path = File.join(base_results_path, reciter_id.to_s, 'segments.db')
      next unless File.exist?(db_path)
      db = db_cache[reciter_id] ||= SQLite3::Database.new(db_path)

      row = db.get_first_row("SELECT words FROM timings WHERE sura = ? AND ayah = ?", surah_number.to_s, ayah_number.to_s)
      next unless row && row[0]

      segments = JSON.parse(row[0])
      word_number = failed_words[0]
      found = segments.find { |w| w[0].to_i == word_number.to_i }

      if found
        failure.update_columns(
          corrected: true,
          corrected_ayah_number: ayah_number,
          corrected_word_number: word_number,
          corrected_start_time: found[1].to_i,
          corrected_end_time: found[2].to_i
        )
      end
    end

    Segments::Failure.where(failure_type: 'MISSED_WORD', corrected: [nil, false]).find_each do |failure|
      reciter_id = failure.reciter_id
      surah_number = failure.surah_number
      ayah_number = failure.ayah_number
      word_number = failure.word_number

      db_path = File.join(base_results_path, reciter_id.to_s, 'segments.db')
      next unless File.exist?(db_path)

      db = @db_cache ||= {}
      db[reciter_id] ||= SQLite3::Database.new(db_path)
      reciter_db = db[reciter_id]

      row = reciter_db.get_first_row("SELECT words FROM timings WHERE sura = ? AND ayah = ?", surah_number.to_s, ayah_number.to_s)
      next unless row && row[0]

      segments = JSON.parse(row[0])

      found = segments.find { |segment| segment[0].to_i == word_number.to_i }

      if found
        failure.update_columns(
          corrected: true,
          corrected_ayah_number: ayah_number,
          corrected_word_number: word_number,
          corrected_start_time: found[1].to_i,
          corrected_end_time: found[2].to_i
        )
      end
    end
  end

  def update_failure_word_numbers

  end

  def detect_word_number_from_text(surah_number, ayah_number, text)
    ayah_words = get_ayah_words(surah_number, ayah_number)
    normalized_text = normalize(text)

    best_match = nil
    min_distance = Float::INFINITY

    ayah_words.each do |word_data|
      word_data[:texts].each do |word_text|
        distance = levenshtein_distance(normalized_text, word_text)

        # Prioritize exact matches
        if distance == 0
          return word_data[:word_number]
        elsif distance < min_distance
          min_distance = distance
          best_match = word_data[:word_number]
        end
      end
    end

    # Return best match if it's close enough (distance <= 2), otherwise nil
    min_distance <= 2 ? best_match : nil
  end

  def detect_merged_word_numbers(surah_number, ayah_number, start_word_number, text)
    ayah_words = get_ayah_words(surah_number, ayah_number)
    normalized_target = normalize(text)

    max_words_to_try = 5 # Try up to 5-word combinations
    best_match = []
    min_distance = Float::INFINITY

    (2..max_words_to_try).each do |count|
      words_group = ayah_words[start_word_number - 1, count]
      break if words_group.size < count

      combinations = words_group.map { |w| w[:texts] }.inject(&:product)
      combinations = combinations.map { |combo| combo.flatten.join } unless words_group.size == 1

      combinations.each do |merged_text|
        normalized_merged = normalize(merged_text)
        distance = levenshtein_distance(normalized_target, normalized_merged)

        if distance < min_distance
          min_distance = distance
          best_match = (start_word_number...(start_word_number + count)).to_a
        end

        return best_match if distance == 0
      end
    end

    min_distance <= 3 ? best_match : []
  end

  protected

  def seed_missed_segments
    reciter_surah_set = Segments::Failure.pluck(:reciter_id, :surah_number).uniq
    reciter_surah_set.each do |entry|
      reciter = entry[0]
      surah = entry[1]
      existing_words = {}

      existing_positions = Segments::Position.where(
        reciter_id: reciter,
        surah_number: surah
      )
      # This surah is not segmented, skip it
      next if existing_positions.blank?

      existing_positions.each do |pos|
        existing_words["#{pos.surah_number}:#{pos.ayah_number}:#{pos.word_number}"] = true
      end

      existing_failures = Segments::Failure.where(
        reciter_id: reciter,
        surah_number: surah
      )

      existing_failures.each do |failure|
        if failure.word_number.blank?
          possible_word = failure.mistake_positions.to_s.split(',').first
          existing_words[possible_word] ||= true
        else
          existing_words["#{failure.surah_number}:#{failure.ayah_number}:#{failure.word_number}"] ||= true
        end
      end

      missed_words = Word
                       .words
                       .where(chapter_id: surah)
                       .where.not(location: existing_words.keys)

      if missed_words.present?
        Segments::Failure.insert_all(
          missed_words.map do |entry|
            s, a, w = entry.location.split(':')

            {
              surah_number: s,
              ayah_number: a,
              word_number: w,
              word_key: entry.location,
              reciter_id: reciter,
              failure_type: "MISSED_WORD",
              start_time: nil,
              end_time: nil,
              mistake_positions: nil,
              text: entry.text_qpc_hafs,
              received_transcript: nil,
              expected_transcript: nil
            }
          end
        )
      end
    end
  end

  def seed_adjusted_segment_positions
    base_results_path = File.join(base_path, 'results')

    reciter_surah_map = Segments::Position
                          .distinct
                          .pluck(:reciter_id, :surah_number)
                          .group_by(&:first)
                          .transform_values do |pairs|
      pairs.map(&:last).uniq
    end

    reciter_surah_map.each do |reciter_id, surahs|
      db_path = File.join(base_results_path, reciter_id.to_s, 'segments.db')
      next unless File.exist?(db_path)
      db = SQLite3::Database.new(db_path)

      surahs.each do |surah_number|
        chapter = Chapter.find(surah_number)
        1.upto(chapter.verses_count) do |ayah_number|
          row = db.get_first_row("SELECT words FROM timings WHERE sura = ? AND ayah = ?", surah_number.to_s, ayah_number.to_s)
          next unless row && row[0]
          ayah_segments = JSON.parse(row[0])
          ayah_segments.each do |segment|
            position = Segments::Position.where(
              reciter_id: reciter_id,
              surah_number: surah_number,
              ayah_number: ayah_number,
              word_number: segment[0].to_i
            ).first

            if position
              position.update_columns(
                corrected_start_time: segment[1].to_i,
                corrected_end_time: segment[2].to_i
              )
            end
          end
        end
      end
    end
  end

  def insert_segment(db, surah_number, ayah_number, start_time, end_time, words)
    words = JSON.dump(words)
    statement = db.prepare("INSERT INTO timings (sura, ayah, start_time, end_time, words) VALUES (?, ?, ?, ?, ?)")
    statement.bind_params(surah_number, ayah_number, start_time, end_time, words)
    statement.execute
    statement.close
  end

  def merge_ayah_segments(words)
    words_timing = []

    words.each_with_index do |current_word, _i|
      if words_timing.empty?
        words_timing << current_word
      else
        last_word = words_timing.last

        if current_word[:word_number] == last_word[:word_number] # same word
          words_timing[-1] = {
            word_number: current_word[:word_number],
            start_time: last_word[:start_time],
            end_time: current_word[:end_time]
          }
        else
          words_timing << current_word
        end
      end
    end

    words_timing
  end

  def process_surah_segments(entries, surah_number)
    ayah_groups = Hash.new { |h, k| h[k] = [] }
    current_ayah = 1
    current_word = 1
    first_ayah_found = false
    @ayah_words_cache = {}

    entries.each do |entry|
      start_time = entry['startTime']
      end_time = entry['endTime']

      ayah = case entry['type']
             when 'POSITION'
               entry.dig('position', 'ayahNumber').to_i
             when 'FAILURE'
               entry.dig('mistakeWithPositions', 'positions', 0, 'ayahNumber').to_i
             else
               next
             end

=begin
TODO: fix missed words 00020043 (501760)
http://localhost:3000/segments/logs?reciter=2&surah=43
http://localhost:3000/segments/timeline?ayah=33&reciter=2&surah=43
{
    "type": "POSITION",
    "startTime": 501760,
    "endTime": 502320,
    "word": "وَلَوْلَا",
    "confidence": -0.14044350385665894,
    "speakerTag": 0,
    "position": {
      "ayahNumber": 33,
      "surahNumber": 43,
      "wordNumber": 1,
      "exactPosition": 63665
    },
    "startingIdentificationIndex": 0,
    "sessionRange": {
      "startSurahNumber": 43,
      "startAyahNumber": 1,
      "endSurahNumber": 43,
      "endAyahNumber": 33
    },
    "mistakeWithPositions": null,
    "isTranscriptFinal": false
  },
  {
    "type": "POSITION",
    "startTime": 504320,
    "endTime": 504360,
    "word": "أَ",
    "confidence": -0.0007187459850683808,
    "speakerTag": 0,
    "position": {
      "ayahNumber": 33,
      "surahNumber": 43,
      "wordNumber": 1,
      "exactPosition": 63665
    },
    "startingIdentificationIndex": 0,
    "sessionRange": {
      "startSurahNumber": 43,
      "startAyahNumber": 1,
      "endSurahNumber": 43,
      "endAyahNumber": 33
    },
    "mistakeWithPositions": null,
    "isTranscriptFinal": false
  }
=end

      if !first_ayah_found
        current_ayah = 1
        first_ayah_found = true
        current_word = 1
        start_time = [0, start_time].min
      else
        current_ayah = ayah
      end

      word_number = case entry['type']
                    when 'POSITION'
                      entry.dig('position', 'wordNumber').to_i
                    when 'FAILURE'
                      detect_failure_word(entry, surah_number, current_ayah, current_word)
                    else
                      next
                    end

      word_number = translate_word(surah_number, current_ayah, word_number)

      ayah_groups[[surah_number, current_ayah]] << {
        word_number: word_number,
        start_time: start_time,
        end_time: end_time
      }
    end

    surah_segments = []
    ayah_groups.each do |(surah, ayah), words|
      words.sort_by! { |w| w[:start_time] }

      adjusted_words = []

      words.each_with_index do |word, i|
        adjusted_start = word[:start_time]
        next_word = words[i + 1]
        adjusted_end = next_word ? [next_word[:start_time] - 200, word[:end_time]].max : word[:end_time]

        adjusted_words << {
          word_number: word[:word_number],
          start_time: adjusted_start,
          end_time: adjusted_end
        }
      end

      adjusted_words = merge_ayah_segments(adjusted_words)

      surah_segments << {
        surah: surah,
        ayah: ayah,
        words: adjusted_words.map { |w| [w[:word_number], w[:start_time], w[:end_time]] }
      }
    end

    surah_segments
  end

  def auto_fix_segments_issues(segments, surah_number)
    fixed_segments = {}

    segments.each_with_index do |segment, index|
      ayah = segment[:ayah]
      words = segment[:words]
      next_segment = segments[index + 1]

      if verse = Verse.find_by(chapter_id: surah_number, verse_number: ayah)
        ayah_words = Word.words.where(verse: verse).order(:position).pluck(:text_uthmani)
        next if words.size == ayah_words.size

        if words.size.zero? && ayah_words.size == 1
          # Single word ayah
          if verse.first_ayah? && next_segment
            next_segment_first_word = next_segment[:words].first
            words = [[1, 0, next_segment_first_word[1] - 200]]
          end
        elsif words.size <= ayah_words.size
          words = adjust_zero_duration_words(words, ayah_words)
          words = fix_segment_for_missing_words(words, ayah_words)
        end

        segment[:start_time] = words.first[1]
        segment[:end_time] = words.last[2]
        segment[:words] = words

        fixed_segments[verse.verse_number] = segment
      end
    end

    fixed_segments.values
  end

  def translate_word(surah, ayah, word)
    surah_mapping = MUSHAF_TRANSLATOR_INDEX[surah.to_s]
    if surah_mapping && surah_mapping[ayah.to_s]
      word_id = word.to_i - 1
      val = surah_mapping[ayah.to_s][word_id.to_s]

      val ? val.to_i + 1 : word
    else
      word
    end
  end

  def calculate_similarity(text1, text2)
    return 0.0 if text1.blank? || text2.blank?
    return 1 if text1 == text2

    text1 = text1.remove_diacritics
    text2 = text2.remove_diacritics

    distance = levenshtein_distance(text1, text2)
    max_length = [text1.length, text2.length].max

    similarity = 1.0 - (distance.to_f / max_length)
    [similarity, distance]
  end

  def levenshtein_distance(str1, str2)
    return str2.length if str1.empty?
    return str1.length if str2.empty?
    return 0 if str1 == str2

    # Convert strings to arrays of characters for easier handling
    s1 = str1.chars
    s2 = str2.chars

    # Create matrix with dimensions (str1.length + 1) x (str2.length + 1)
    rows = s1.length + 1
    cols = s2.length + 1
    matrix = Array.new(rows) { Array.new(cols, 0) }

    # Initialize first row and column
    (0...rows).each { |i| matrix[i][0] = i }
    (0...cols).each { |j| matrix[0][j] = j }

    # Fill the matrix
    (1...rows).each do |i|
      (1...cols).each do |j|
        if s1[i - 1] == s2[j - 1]
          # Characters match, no operation needed
          matrix[i][j] = matrix[i - 1][j - 1]
        else
          # Take minimum of three operations: insert, delete, substitute
          matrix[i][j] = [
            matrix[i - 1][j] + 1, # deletion
            matrix[i][j - 1] + 1, # insertion
            matrix[i - 1][j - 1] + 1 # substitution
          ].min
        end
      end
    end

    matrix[rows - 1][cols - 1]
  end

  def normalize(text)
    return '' if text.nil?
    text.tr('ًٌٍَُِّْـٰ', '')
  end

  def detect_failure_word(entry, surah_number, ayah, last_word)
    mistake = entry['mistakeWithPositions']
    received_text = normalize(entry['word'].to_s)
    expected_text = normalize(mistake['expectedTranscript'].to_s)

    return nil if (mistake['positions'].nil? && (received_text.blank? && expected_text.blank?))

    position_data = mistake['positions'].first
    expected_word_number = position_data['wordIndex'].to_i + 1

    ayah_words = get_ayah_words(surah_number, ayah)

    # Find best match using Levenshtein distance
    best_match = nil
    min_distance = Float::INFINITY
    search_radius = 1 # Words around expected position to check

    # Calculate search range
    start_index = [0, expected_word_number - search_radius].max
    end_index = [ayah_words.length - 1, expected_word_number + search_radius].min

    (start_index..end_index).each do |idx|
      p = entry['mistakeWithPositions']['positions'][0]

      idx = [0, idx -1].max
      word_data = ayah_words[idx]

      texts = word_data[:texts]
      least_distance = Float::INFINITY
      distance = Float::INFINITY

      texts.each do |word_text|
        distance = levenshtein_distance(received_text, word_text)
        expected_text_distance = levenshtein_distance(expected_text, word_text)

        if distance == 0 || expected_text_distance == 0
          puts "found 000"
          return word_data[:word_number]
        end

        if distance < least_distance
          least_distance = distance
        end
      end

      # Prioritize exact matches
      if distance == 0
        return word_data[:word_number]
      elsif distance < min_distance
        min_distance = distance
        best_match = word_data[:word_number]
      end
    end

    # Return best match if it's close enough, otherwise expected position
    min_distance <= 2 ? best_match : expected_word_number
  end

  def get_ayah_words(surah_id, ayah_number)
    @ayah_words_cache ||= {}
    key = "#{surah_id}:#{ayah_number}"

    return @ayah_words_cache[key] if @ayah_words_cache[key]

    verse = Verse.find_by(verse_key: key)
    words = verse.words.words # skip ayah marker

    @ayah_words_cache[key] = words.map do |word|
      {
        texts: [
          normalize(word.text_imlaei_simple),
          normalize(word.text_imlaei),
          normalize(word.text_uthmani_simple),
        # normalize(word.text_uthmani),
        ].uniq,
        word_number: word.position
      }
    end
  end

  def create_recitation_segments_db(base_path)
    FileUtils.rm("#{base_path}/segments.db") if File.exist?("#{base_path}/segments.db")

    db = SQLite3::Database.new "#{base_path}/segments.db"
    db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS timings (
      sura TEXT,
      ayah TEXT,
      start_time TEXT,
      end_time TEXT,
      words TEXT
    );
    SQL

    db
  end

  def seed_raw_logs
    segments_logs_path = "#{base_path}/logs/*.log"
    batch_size = 1000
    log_entries = []

    Dir.glob(segments_logs_path).each do |file_path|
      puts "Processing #{file_path}"

      content = File.readlines(file_path)
      next if content.blank?

      filename = File.basename(file_path)
      reciter_id, surah_number = parse_reciter_and_surah(filename)

      content.each do |line|
        match = line.match(/^\[(.*?)\]\s*(.*)/)
        next unless match

        time = match[1]
        log = match[2].to_s.strip
        next if log.blank?

        begin
          timestamp = Time.iso8601(time).to_i
        rescue ArgumentError
          puts "Invalid timestamp format in #{file_path}: #{time}"
          next
        end

        log_entries << {
          surah_number: surah_number,
          reciter_id: reciter_id,
          timestamp: timestamp,
          log: log
        }

        # Bulk insert when batch size is reached
        if log_entries.size >= batch_size
          Segments::Log.insert_all(log_entries)
          log_entries.clear
        end
      end
    end

    if log_entries.any?
      Segments::Log.insert_all(log_entries)
    end

    puts "Processed #{Dir.glob(segments_logs_path).count} log files"
  end

  def seed_segments(content, reciter_id, surah_number)
    type_counts = Hash.new(0)
    data = JSON.parse(content)

    data.each do |entry|
      type = entry["type"]
      type_counts[type] += 1

      mistake = entry["mistakeWithPositions"] || {}

      word_info = entry["position"]
      ayah_number = word_info&.[]("ayahNumber")
      word_number = word_info&.[]("wordNumber")
      word_key = (ayah_number && word_number) ? "#{surah_number}:#{ayah_number}:#{word_number}" : ""

      if type == 'FAILURE'
        type_counts['FAILURE'] += 1
        mistake_positions = (mistake["positions"] || []).map do |pos|
          "#{surah_number}:#{pos['ayahNumber']}:#{pos['wordIndex'] + 1}"
        end.join(',')

        Segments::Failure.insert_all(
          [{
             surah_number: surah_number,
             ayah_number: ayah_number,
             word_number: word_number,
             reciter_id: reciter_id,
             word_key: word_key,
             text: entry['word'],
             failure_type: mistake["mistakeType"],
             received_transcript: mistake["receivedTranscript"],
             expected_transcript: mistake["expectedTranscript"],
             start_time: entry["startTime"],
             end_time: entry["endTime"],
             mistake_positions: mistake_positions
           }]
        )
      end

      if ayah_number && word_number && entry["startTime"] && entry["endTime"]
        Segments::Position.insert_all(
          [{
             surah_number: surah_number,
             ayah_number: ayah_number,
             word_number: word_number,
             word_key: word_key,
             reciter_id: reciter_id,
             start_time: entry["startTime"],
             end_time: entry["endTime"]
           }])
      end
    end

    track_detection(type_counts, reciter_id, surah_number)
  end

  def track_detection(detections, reciter_id, surah_number)
    detections.each do |type, count|
      Segments::Detection.insert_all(
        [{
           surah_number: surah_number,
           reciter_id: reciter_id,
           detection_type: type,
           count: count
         }]
      )
    end
  end

  def parse_reciter_and_surah(filename)
    reciter_id = filename[0..3].to_i
    surah_number = filename[4..7].to_i

    [reciter_id, surah_number]
  end

  def seed_recitations
    segmented_recitations.each do |recitation|
      resource_content = recitation.get_resource_content
      base_url = resource_content.meta_value("audio-cdn-url") || "https://download.quranicaudio.com"
      path = recitation.relative_path
      path = path.chomp('/') if path.end_with?('/')

      sample_audio_url = recitation.chapter_audio_files.where(chapter_id: 1).first.audio_url
      prefix_file_name = sample_audio_url.split('/').last.start_with?('00')
      chapters = Segments::Position.where(reciter_id: recitation.id).pluck(:surah_number).uniq

      Segments::Reciter.where(id: recitation.id).first_or_create(
        name: recitation.humanize,
        audio_cdn_path: "#{base_url}/#{path}",
        prefix_file_name: prefix_file_name,
        segmented_chapters: chapters.join(',')
      )
    end
  end

  def setup_db
    FileUtils.rm(db_file) if File.exist?(db_file)

    Segments::Base.establish_connection(
      adapter: 'sqlite3',
      database: db_file
    )
    connection = Segments::Base.connection

    connection.create_table :segments_reciters do |t|
      t.string :name
      t.string :audio_cdn_path
      t.string :segmented_chapters
      t.boolean :prefix_file_name, default: false
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

    connection.create_table :segments_state_machine_logs do |t|
      t.integer :surah_number
      t.integer :reciter_id
      t.text :state_machine_data
    end
  end

  def segmented_recitations
    return @recitations if @recitations.present?

    recitation_ids = []
    Dir.glob(segments_logs_path) do |file_path|
      session_id = file_path[%r{vs_logs/([^/]+)/}, 1]
      reciter_id = session_id[0..3].to_i
      recitation_ids << reciter_id
    end

    @recitations = Audio::Recitation.where(id: recitation_ids.uniq)
  end

  def adjust_zero_duration_words(words, ayah_words)
    fixed_words = words.map(&:dup)

    (0...fixed_words.size - 1).each do |i|
      current_word = fixed_words[i]
      next_word = fixed_words[i + 1]

      if current_word[2] == next_word[1] && current_word[1] == current_word[2]
        total_time = next_word[2] - current_word[1]

        word1 = ayah_words[i]
        word2 = ayah_words[i + 1]

        duration1, duration2 = divide_segment_time(total_time, word1, word2)

        if duration1 && duration2
          current_word[2] = current_word[1] + duration1
          next_word[1] = current_word[2]
          next_word[2] = next_word[1] + duration2
        end
      end
    end

    fixed_words
  end

  def fix_segment_for_missing_words(segments, ayah_words)
    #TODO: use detect_merged_word_numbers to fix merged words timing
    # http://localhost:3000/segments/timeline?ayah=31&reciter=2&surah=41
    # received: رَحِيمْرَحِيمْ
    # expected: رَّحِيمٍ
    #
    # We should be able to auto fix missing word, time between two words
    # http://localhost:3000/segments/timeline?ayah=19&reciter=2&surah=41
    missed_segments = []

    ayah_words.each_with_index do |word, index|
      if segments[index].blank?
        missed_segments << index
      end
    end

    missed_segments.each do |index|
      previous_segment = segments[index - 1]
      word_number, start_time, end_time = previous_segment
      total_duration = end_time - start_time

      duration1, duration2 = divide_segment_time(total_duration, ayah_words[index - 1], ayah_words[index])
      next unless duration1 && duration2

      previous_segment[2] = start_time + duration1
      segments[index - 1] = previous_segment
      segments[index] = [
        word_number + 1,
        previous_segment[2],
        previous_segment[2] + duration2
      ]
    end

    segments
  end

  def divide_segment_time(total_duration, first_word_text, second_word_text)
    score1 = calculate_word_text_score(first_word_text)
    score2 = calculate_word_text_score(second_word_text)
    total_score = score1 + score2
    return if total_score == 0

    duration1 = (score1.to_f / total_score * total_duration).round
    duration2 = total_duration - duration1

    [duration1, duration2]
  end

  def calculate_word_text_score(word)
    base_score = word.remove_diacritics.length

    diacritic_score = word.chars.sum do |char|
      MADD_DIACRITICS[char] || 0
    end

    base_score + diacritic_score
  end
end
