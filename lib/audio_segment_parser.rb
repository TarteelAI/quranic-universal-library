require 'json'
require 'oj'

class AudioSegmentParser
  MUSHAF_TRANSLATOR_INDEX = Oj.load(File.read("lib/data/mushaf-translator-index.json"))

  attr_reader :file_path,
              :reciter_id,
              :surah_number,
              :positions,
              :failures,
              :last_word_number,
              :last_translated_word_number,
              :first_ayah_detected,
              :first_word_detected

  def initialize(file_path)
    @file_path = file_path
    @reciter_id, @surah_number = extract_ids_from_path(file_path)
    @positions = []
    @failures = []
    @last_word_number = nil
    @last_translated_word_number = nil
    @first_ayah_detected = false
    @first_word_detected = false
  end

  def run
    data = load_data
    data.each do |entry|
      begin
        case entry['type']
        when 'POSITION'
          process_position(entry)
        when 'FAILURE'
          process_failure(entry)
        end
      rescue => e
        puts "Error processing file #{file_path}: \n Entry: #{entry.inspect} Error: #{e.message} "
        puts e.backtrace.first(3).join("\n  ")
        break
      end
    end
  end

  def fix_missing_positions
    positions_by_ayah = positions.clone.group_by { |pos| pos[:ayah] }

    positions_by_ayah.each do |ayah_number, ayah_positions|
      ayah_words = get_ayah_words(surah_number, ayah_number)

      expected_word_numbers = (1..ayah_words.length).to_a
      existing_word_numbers = ayah_positions.map { |pos| pos[:word] }
      missing_word_numbers = expected_word_numbers - existing_word_numbers

      next if missing_word_numbers.empty?

      missing_word_numbers.each do |missing_word_number|
        last_word_position = ayah_positions.max_by { |pos| pos[:word] }
        next unless last_word_position

        word_data = ayah_words[missing_word_number - 1]
        last_word = ayah_words[last_word_position[:word] - 1]

        next unless word_data

        word_text = word_data[:texts][1] || word_data[:texts].first
        last_word_text = last_word[:texts][1] || last_word[:texts].first

        last_word_time, word_time = divide_segment_time(
          last_word_position[:start_time],
          last_word_position[:end_time],
          last_word_text,
          word_text
        )

        # missing_count = missing_word_numbers.length
        # total_duration = last_word_position[:end_time] - last_word_position[:start_time]

        # time_per_word = total_duration / (missing_count + 1)
        # word_start_time = last_word_position[:start_time] + (time_per_word * (missing_word_numbers.index(missing_word_number) + 1))
        # word_end_time = word_start_time + time_per_word

        # if missing_word_numbers.index(missing_word_number) == 0
        last_word_position[:end_time] = last_word_time[1]
        # end

        missing_position = {
          surah: surah_number,
          ayah: ayah_number,
          word: missing_word_number,
          start_time: word_time[0],
          end_time: word_time[1],
          text: word_text,
          failure_data: {
            type: 'missing_word',
            expected_text: word_text
          }
        }

        insert_index = positions.index { |pos| pos[:ayah] == ayah_number && pos[:word] > missing_word_number }
        if insert_index
          positions.insert(insert_index, missing_position)
        else
          positions << missing_position
        end
      end
    end
  end

  def stats
    data = load_data
    position_entries = data.select { |entry| entry['type'] == 'POSITION' }
    failure_entries = data.select { |entry| entry['type'] == 'FAILURE' }

    {
      total_entries: data.size,
      positions: position_entries.size,
      failures: failure_entries.size,
    }
  end

  private

  def load_data
    return @data if @data
    @data = File.read(file_path)
    return [] if @data.length < 10 # Skip empty or too short files
    @data = JSON.parse(@data)
  end

  def extract_ids_from_path(file_path)
    folder_name = File.basename(File.dirname(file_path))

    # First 4 digits = reciter ID, last 4 digits = surah number
    reciter_id = folder_name[0..2].to_i
    surah_number = folder_name[3..5].to_i

    [reciter_id, surah_number]
  end

  def process_position(entry)
    position_data = entry['position']

    ayah = position_data['ayahNumber']
    word_number = position_data['wordNumber']
    received_text = entry['word']

    if @last_word_number == word_number
      # Check if this is actually next word
      detect_word, score = detect_failure_word(received_text, ayah, last_translated_word_number + 1)

      # matching score 2 is arbitrary threshold to avoid false positives
      # replace with this some cleaver logic to detect best score based on word text length
      if detect_word && detect_word > word_number && score <= 2
        word_number = detect_word
      end
    end

    track_position(
      ayah: ayah,
      word_number: word_number,
      start_time: entry['startTime'],
      text: received_text,
      end_time: entry['endTime']
    )
  end

  def track_position(ayah:, word_number:, start_time:, end_time:, text:, failure_data: {})
    translated_word_number = translate_imlaei_word_to_uthmani(surah_number, ayah, word_number)

    if !first_ayah_detected
      @first_ayah_detected = true

      verse = Verse.where(chapter_id: surah_number, verse_number: 1).first
      if verse.has_harooq_muqattaat? || word_number.to_i > 1
        ayah = verse.verse_number
        if !first_word_detected
          word_number = 1
          translated_word_number = 1
        end
      end

      @first_word_detected = true
    end

    word = Word.find_by_location("#{surah_number}:#{ayah}:#{translated_word_number}")

    if word.blank?
      translated_word_number = @last_translated_word_number
      word_number = @last_word_number
    end

    @last_word_number = word_number
    @last_translated_word_number = translated_word_number

    positions.push(
      {
        surah: surah_number,
        ayah: ayah,
        word: translated_word_number,
        start_time: start_time,
        end_time: end_time,
        text: text,
        failure_data: failure_data
      }
    )

    # TODO: What if reciter repeated the last few words?
    if word.last_word?
      @last_word_number = 1
      @last_translated_word_number = 1
    end
  end

  def process_failure(entry)
    mistake = entry['mistakeWithPositions']
    return unless mistake

    start_time = entry['startTime']
    end_time = entry['endTime']

    expected_text = mistake['expectedTranscript']
    received_text = mistake['receivedTranscript']
    ayah_number = mistake['positions'][0]['ayahNumber']
    word_index = mistake['positions'][0]['wordIndex'] + 1

    failure_data = {
      surah_number: surah_number,
      ayah_number: ayah_number,
      word_number: word_index,
      word_key: "#{surah_number}:#{ayah_number}:#{word_index}",
      text: entry['word'],
      reciter_id: reciter_id,
      failure_type: mistake['mistakeType'],
      received_transcript: received_text,
      expected_transcript: expected_text,
      start_time: start_time,
      end_time: end_time,
      mistake_positions: mistake['positions'].to_json,
      corrected: false
    }
    
    failures << failure_data

=begin
    failure_data = {
      expected_text: expected_text,
      received_text: received_text,
      ayah_number: ayah_number,
      type: mistake['mistakeType']
    }
=end

    if !first_word_detected
      @last_word_number ||= 1
      last_translated_word_number ||= 1
    end

    # Check if we've merged words
    @last_translated_word_number ||= translate_imlaei_word_to_uthmani(surah_number, ayah_number, @last_word_number)
    possible_ayah_merged_words = detect_merged_word_numbers(received_text, ayah_number, @last_translated_word_number)

    if possible_ayah_merged_words.blank?
      possible_ayah_merged_words = detect_merged_word_numbers(received_text, ayah_number, @last_translated_word_number + 1)
    end

    if possible_ayah_merged_words.present?
      # Split the time between the merged words
      if possible_ayah_merged_words.size == 1
        uthmani_word = translate_uthmani_word_to_imlaei(
          surah_number,
          ayah_number,
          possible_ayah_merged_words.first
        )

        track_position(
          ayah: ayah_number,
          word_number: uthmani_word.is_a?(Array) ? uthmani_word.first : uthmani_word,
          start_time: start_time,
          end_time: end_time,
          text: received_text,
          failure_data: failure_data
        )
      else
        ayah_words = get_ayah_words(surah_number, ayah_number)

        first_word_texts = ayah_words[possible_ayah_merged_words.first - 1][:texts]
        second_word_texts = ayah_words[possible_ayah_merged_words.last - 1][:texts]

        first_word_text = first_word_texts[1] || first_word_texts.first
        second_word_text = second_word_texts[1] || second_word_texts.first

        first_word_time, second_word_time = divide_segment_time(start_time, end_time, first_word_text, second_word_text)

        uthmani_word_1 = translate_uthmani_word_to_imlaei(
          surah_number,
          ayah_number,
          possible_ayah_merged_words.first
        )

        uthmani_word_2 = translate_uthmani_word_to_imlaei(
          surah_number,
          ayah_number,
          possible_ayah_merged_words.last
        )

        track_position(
          ayah: ayah_number,
          word_number: uthmani_word_1.is_a?(Array) ? uthmani_word_1.first : uthmani_word_1,
          start_time: first_word_time[0],
          end_time: first_word_time[1],
          text: first_word_text,
          failure_data: failure_data,
          )

        track_position(
          ayah: ayah_number,
          word_number: uthmani_word_2.is_a?(Array) ? uthmani_word_2.first : uthmani_word_2,
          start_time: second_word_time[0],
          end_time: second_word_time[1],
          text: second_word_text,
          failure_data: failure_data
        )
      end
    elsif (detect_word, _score = detect_failure_word(expected_text, ayah_number, @last_translated_word_number))
      uthmani_word = translate_uthmani_word_to_imlaei(
        surah_number,
        ayah_number,
        detect_word
      )

      track_position(
        ayah: ayah_number,
        word_number: uthmani_word.is_a?(Array) ? uthmani_word.first : uthmani_word,
        start_time: start_time,
        end_time: end_time,
        text: expected_text,
        failure_data: failure_data
      )
    else
=begin
      track_failure(
        ayah: ayah_number,
        start_time: start_time,
        end_time: end_time,
        text: received_text,
        received_text: received_text
      )
=end
    end
  end

  def track_failure(ayah:, start_time:, end_time:, text:, received_text:)
    failures.push(
      {
        surah: surah_number,
        ayah: ayah,
        start_time: start_time,
        end_time: end_time,
        text: text,
        received_text: received_text
      }
    )
  end

  def get_ayah_words(surah_number, ayah_number)
    @ayah_words_cache ||= {}
    key = "#{surah_number}:#{ayah_number}"

    return @ayah_words_cache[key] if @ayah_words_cache[key]

    verse = Verse.find_by(verse_key: key)
    return [] unless verse

    words = verse.words.words # skip ayah marker

    @ayah_words_cache[key] = words.map do |word|
      {
        texts: [
          normalize_text(word.text_imlaei_simple),
          normalize_text(word.text_imlaei),
          normalize_text(word.text_uthmani_simple),
        # normalize_text(word.text_uthmani), # Commented out as in original
        ].uniq,
        word_number: word.position
      }
    end
  end

  def normalize_text(text)
    return '' if text.nil?
    text.tr('ًٌٍَُِّْـٰ', '')
  end

  def detect_merged_word_numbers(text, ayah_number, start_word_number)
    ayah_words = get_ayah_words(surah_number, ayah_number)
    normalized_target = normalize_text(text)
    # Remove consecutive duplicate letters
    # "اقةة" → "اقة"
    normalized_clean_target = normalized_target.gsub(/(.)\1+/, '\1')

    max_words_to_try = 3
    best_match = []
    best_match_clean = []
    min_distance = min_distance_clean = Float::INFINITY

    # Special case: repeat first word twice
    words_group = ayah_words[start_word_number - 1, 1] * 2
    best_match, min_distance = check_merged_word_combinations(words_group, 1, normalized_target, start_word_number, best_match, min_distance)
    best_match_clean, min_distance_clean = check_merged_word_combinations(words_group, 1, normalized_clean_target, start_word_number, best_match_clean, min_distance_clean)

    if min_distance <= 3 || min_distance_clean <= 3
      return filter_best_matched_ayah_words(best_match, ayah_words)
    end

    # Try 2..max_words_to_try combinations
    (2..max_words_to_try).each do |count|
      words_group = ayah_words[start_word_number - 1, count]
      best_match, distance = check_merged_word_combinations(words_group, count, normalized_target, start_word_number, best_match, min_distance)
      best_match_clean, clean_distance = check_merged_word_combinations(words_group, count, normalized_clean_target, start_word_number, best_match_clean, min_distance_clean)

      if distance == 0 || clean_distance == 0
        return filter_best_matched_ayah_words(best_match, ayah_words)
      end

      if distance < min_distance
        min_distance = distance
      end

      if clean_distance < min_distance_clean
        min_distance_clean = clean_distance
      end
    end

    (min_distance <= 3 || min_distance_clean <= 3) ? filter_best_matched_ayah_words(best_match, ayah_words) : []
  end

  def check_merged_word_combinations(words_group, count, target, start_word_number, best_match, min_distance)
    combinations = words_group.map { |w| w[:texts] }.inject(&:product)
    combinations = combinations.map { |combo| combo.flatten.join } unless words_group.size == 1

    combinations.each do |merged_text|
      distance = levenshtein_distance(target, merged_text)

      if distance < min_distance
        min_distance = distance
        best_match = (start_word_number...(start_word_number + count)).to_a
      end

      return [best_match, 0] if distance == 0 # early exit
    end

    [best_match, min_distance]
  end

  def filter_best_matched_ayah_words(best_match, ayah_words)
    return [] if best_match.blank?

    best_match.select do |word|
      ayah_words.detect do |a| a[:word_number] == word end
    end
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

  def translate_imlaei_word_to_uthmani(surah, ayah, imlaei_word)
    surah_mapping = MUSHAF_TRANSLATOR_INDEX[surah.to_s]
    if surah_mapping && surah_mapping[ayah.to_s]
      word_id = imlaei_word.to_i - 1
      val = surah_mapping[ayah.to_s][word_id.to_s]

      val ? val.to_i + 1 : imlaei_word
    else
      imlaei_word
    end
  end

  def translate_uthmani_word_to_imlaei(surah, ayah, uthmani_word)
    surah_mapping = MUSHAF_TRANSLATOR_INDEX[surah.to_s]

    if surah_mapping && surah_mapping[ayah.to_s]
      uthmani_index = uthmani_word.to_i - 1

      imlaei_entry = surah_mapping[ayah.to_s].find { |imlaei, uthmani| uthmani == uthmani_index }
      if imlaei_entry
        return imlaei_entry[1].to_i == 0 ? [1, imlaei_entry.first.to_i + 1] : uthmani_word
      end
    end

    uthmani_word
  end

  def detect_failure_word(text, ayah, expected_word_number)
    text = normalize_text(text)
    ayah_words = get_ayah_words(surah_number, ayah)

    best_match = nil
    min_distance = Float::INFINITY
    search_radius = 1 # Words around expected position to check

    start_index = [0, expected_word_number - search_radius].max
    end_index = [ayah_words.length - 1, expected_word_number + search_radius].min

    (start_index..end_index).each do |idx|
      idx = [0, idx -1].max
      word_data = ayah_words[idx]

      texts = word_data[:texts]
      least_distance = Float::INFINITY
      distance = Float::INFINITY

      texts.each do |word_text|
        distance = levenshtein_distance(text, word_text)

        if distance == 0 # Perfect match
          return [word_data[:word_number], distance]
        end

        if distance < least_distance
          least_distance = distance
        end
      end

      if distance == 0
        return word_data[:word_number]
      elsif distance < min_distance
        min_distance = distance
        best_match = word_data[:word_number]
      end
    end

    [best_match, min_distance]
  end

  def divide_segment_time(start_time, end_time, first_word_text, second_word_text)
    return [[start_time, end_time]] if second_word_text.blank?

    total_duration = end_time - start_time
    score1 = calculate_word_text_score(first_word_text)
    score2 = calculate_word_text_score(second_word_text)
    total_score = score1 + score2
    return [[start_time, end_time]] if total_score == 0

    first_word_duration = (score1.to_f / total_score * total_duration).round

    first_word_time = [start_time, start_time + first_word_duration]
    second_word_time = [start_time + first_word_duration, end_time]

    [
      first_word_time,
      second_word_time
    ]
  end

  LETTER_SCORES = {
    "ٓ" => 6,
    "" => 4,
    "آّ" => 6,
    "ٰ" => 4
  }

  def calculate_word_text_score(text)
    base_score = normalize_text(text).length

    diacritic_score = text.chars.sum do |char|
      LETTER_SCORES[char] || 0
    end

    base_score + diacritic_score
  end
end
