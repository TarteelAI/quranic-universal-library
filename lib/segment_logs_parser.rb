require 'sqlite3'
require 'fileutils'

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
    @base_path = "/Volumes/Data/qul-segments/15-july"
    @segments_logs_path = "#{@base_path}/vs_logs/**/time-machine.json"
    @db_file = "#{@base_path}/segments_database.db"

    setup_db
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
      next if reciter_id != 10

      puts "Processing #{file_path}"
      export_path = "#{base_path}/results/#{reciter_id}"
      FileUtils.mkdir_p("#{export_path}/json")

      RECITER_SEGMENTS_DB[reciter_id] ||= create_recitation_segments_db(export_path)
      db = RECITER_SEGMENTS_DB[reciter_id]

      segments = process_surah_segments(data, surah_number)
      json_data = {}

      if segments.blank?
        puts "No segments found for #{file_path}"
        next
      end

      segments.each do |segment|
        words = segment[:words]
        surah = segment[:surah]
        ayah_number = segment[:ayah]
        start_time = segment[:start_time]
        end_time = segment[:end_time]

        begin
          if verse = Verse.find_by(chapter_id: surah_number, verse_number: ayah_number)
            ayah_words = Word.words.where(verse: verse).order(:position).pluck(:text_uthmani)

            # TODO: fix 69:1-2
            if words.size <= ayah_words.size
              words = adjust_zero_duration_words(words, ayah_words)
            end

            json_data[ayah_number] = words
            insert_segment(db, surah_number, ayah_number, start_time, end_time, words)
          else
            puts "Verse not found for Surah #{surah_number}, Ayah #{ayah_number}"
            next
          end
        rescue Exception => e
          binding.pry if @debug.nil?
        end
      end

      File.open("#{export_path}/json/#{surah_number}.json", 'w') do |f|
        f.puts json_data.to_json
      end
    end
  end

  def update_fixed_failures

  end

  protected

  def insert_segment(db, surah_number, ayah_number, start_time, end_time, words)
    words = JSON.dump(words)
    statement = db.prepare("INSERT INTO timings (sura, ayah, start_time, end_time, words) VALUES (?, ?, ?, ?, ?)")
    statement.bind_params(surah_number, ayah_number, start_time, end_time, words)
    statement.execute
    statement.close
  end

  def process_surah_segments(entries, surah_number)
    ayah_groups = Hash.new { |h, k| h[k] = [] }
    current_ayah = 1
    current_word = 1
    last_end_time = nil
    @ayah_words_cache = {}

    entries.each do |entry|
      start_time = entry['startTime']
      end_time = entry['endTime']
      word_text = entry['word']

      ayah = case entry['type']
             when 'POSITION'
               entry.dig('position', 'ayahNumber').to_i
             when 'FAILURE'
               entry.dig('mistakeWithPositions', 'positions', 0, 'ayahNumber').to_i
             else
               next
             end

      if ayah != current_ayah
        current_ayah = ayah
        current_word = 1
      end

      word_number = case entry['type']
                    when 'POSITION'
                      entry.dig('position', 'wordNumber').to_i
                    when 'FAILURE'
                      find_word_number(entry, surah_number, ayah, current_word)
                    else
                      next
                    end

      word_number = translate_word(surah_number, ayah, word_number)

      if word_number > current_word
        (current_word..word_number - 1).each do |skipped_num|
          ayah_groups[[surah_number, current_ayah]] << {
            word_number: skipped_num,
            start_time: last_end_time || start_time,
            end_time: last_end_time || start_time,
            skipped: true
          }
        end
        current_word = word_number
      end

      # Add current word
      ayah_groups[[surah_number, ayah]] << {
        word_number: word_number,
        start_time: start_time,
        end_time: end_time,
        skipped: false
      }

      current_word = word_number + 1
      last_end_time = end_time
    end

    # Process groups and adjust times
    result = []
    ayah_groups.each do |(surah, ayah), words|
      # Remove duplicates and sort by word number
      words.uniq! { |w| w[:word_number] }
      words.sort_by! { |w| w[:word_number] }

      adjusted_words = []
      previous_end = nil

      words.each do |word|
        adjusted_start = previous_end || word[:start_time]
        adjusted_end = word[:skipped] ? adjusted_start : word[:end_time]

        adjusted_words << {
          word_number: word[:word_number],
          start_time: adjusted_start,
          end_time: adjusted_end,
          skipped: word[:skipped]
        }

        previous_end = adjusted_end
      end

      next if adjusted_words.empty?

      result << {
        surah: surah,
        ayah: ayah,
        start_time: adjusted_words.first[:start_time],
        end_time: adjusted_words.last[:end_time],
        words: adjusted_words.map { |w| [w[:word_number], w[:start_time], w[:end_time]] }
      }
    end

    result.sort_by! { |a| [a[:surah], a[:ayah]] }
    result
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
    text.tr('ًٌٍَُِّْـ', '')
  end

  def find_word_number(entry, surah_number, ayah, current_word)
    mistake = entry['mistakeWithPositions']
    return nil if mistake.nil? || mistake['positions'].nil?

    position_data = mistake['positions'].first
    return nil if position_data.nil?

    expected_word_index = position_data['wordIndex'].to_i
    expected_word_number = expected_word_index + 1
    received_text = entry['word']

    return nil if received_text.nil? || received_text.empty?

    # Get words for the ayah
    ayah_words = get_ayah_words(surah_number, ayah)
    return expected_word_number if ayah_words.empty?

    normalized_received = normalize(received_text)

    # Find best match using Levenshtein distance
    best_match = nil
    min_distance = Float::INFINITY
    search_radius = 3 # Words around expected position to check

    # Calculate search range
    start_index = [0, expected_word_index - search_radius].max
    end_index = [ayah_words.length - 1, expected_word_index + search_radius].min

    (start_index..end_index).each do |idx|
      word_data = ayah_words[idx]

      texts = word_data[:texts]
      least_distance = Float::INFINITY
      distance = Float::INFINITY

      texts.each do |word_text|
        distance = levenshtein_distance(normalized_received, word_text)
        if distance == 0
          word_data[:word_number]
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

    words = Word.unscoped
                .joins(:verse)
                .where(verses: { chapter_id: surah_id, verse_number: ayah_number })
                .order('words.position ASC')

    @ayah_words_cache[key] = words.map do |word|
      {
        texts: [
          normalize(word.text_imlaei_simple),
          normalize(word.text_imlaei),
        # normalize(word.text_uthmani_simple),
        # normalize(word.text_uthmani),
        ],
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

    Dir.glob(segments_logs_path).each do |file_path|
      puts "Processing #{file_path}"

      content = File.readlines(file_path)
      next if content.blank?

      filename = File.basename(file_path)
      reciter_id, surah_number = parse_reciter_and_surah(filename)

      content.each do |line|
        match = line.match(/^\[(.*?)\]\s*(.*)/)
        time = match[1]
        time = Time.iso8601(time)

        if (log = match[2].to_s.strip).present?
          Segments::Log.insert_all(
            [
              {
                surah_number: surah_number,
                reciter_id: reciter_id,
                timestamp: time.to_i,
                log: log
              }
            ]
          )
        end
      end
    end
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
      word_key = (ayah_number && word_number) ? "#{surah_number}:#{ayah_number}:#{word_number}" : "unknown"

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
    end

    connection.create_table :segments_positions do |t|
      t.integer :surah_number
      t.integer :ayah_number
      t.integer :word_number
      t.string :word_key
      t.integer :reciter_id
      t.integer :start_time
      t.integer :end_time
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
      current = fixed_words[i]
      nxt = fixed_words[i + 1]

      if current[2] == nxt[1] && current[1] == current[2]
        total_time = nxt[2] - current[1]

        word1 = ayah_words[i]
        word2 = ayah_words[i + 1]

        score1 = calculate_word_text_score(word1)
        score2 = calculate_word_text_score(word2)
        score_sum = score1 + score2

        next if score_sum.zero?

        duration1 = (score1.to_f / score_sum * total_time).round
        duration2 = total_time - duration1

        current[1] = current[1]
        current[2] = current[1] + duration1
        nxt[1] = current[2]
        nxt[2] = nxt[1] + duration2

        break # only fix one pair
      end
    end

    fixed_words
  end

  def calculate_complexity_score(text)
    return 1 if text.nil? || text.empty?

    # Base score: word length (normalized without diacritics)
    normalized = text.tr('ًٌٍَُِّْـ', '')
    score = normalized.length * 2

    # Bonus for special characters that indicate longer pronunciation
    score += 5 if normalized.include?('ا') # Alif (long vowel)
    score += 5 if normalized.include?('و') # Waw (long vowel)
    score += 5 if normalized.include?('ي') # Ya (long vowel)
    score += 8 if normalized.include?('ّ') # Shaddah (doubled consonant)
    score += 10 if normalized.include?('آ') # Maddah (extended alif)
    score += 10 if normalized.include?('ى') # Alif maqsura

    score
  end

  def calculate_word_text_score(word)
    base_score = word.remove_diacritics.length

    diacritic_score = word.chars.sum do |char|
      MADD_DIACRITICS[char] || 0
    end

    base_score + diacritic_score
  end
end