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
        when 'SPECIAL_CASE'
          process_special_case(entry)
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
        word_data = ayah_words[missing_word_number - 1]

        if missing_word_number == 1
          # First word was merged with last word of previous ayah
          last_ayah_positions = positions_by_ayah[ayah_number - 1]
          next if last_ayah_positions.nil? # Multiple missing ayahs
          previous_word_position = last_ayah_positions[-1]
          next if previous_word_position.blank?

          last_ayah_words = get_ayah_words(surah_number, ayah_number - 1)
          last_word = last_ayah_words[-1]

          timing = divide_segment_time(
            previous_word_position[:start_time],
            previous_word_position[:end_time],
            [last_word[:text], word_data[:text]]
          )

          previous_word_time = timing[0]
          word_time = timing[1]

          previous_word_position[:end_time] = previous_word_time[1]

          missing_position = {
            surah: surah_number,
            ayah: ayah_number,
            word: missing_word_number,
            start_time: word_time[0],
            end_time: word_time[1],
            text: word_data[:text],
            failure_data: {
              type: 'missing_word',
              expected_text: word_data[:text]
            }
          }
          insert_index = positions.index(previous_word_position)

          if insert_index
            positions.insert(insert_index + 1, missing_position)
          else
            positions << missing_position
          end
        else
          previous_word_position = ayah_positions
                                     .select { |pos| pos[:word] == missing_word_number - 1 }
                                     .first
          next unless previous_word_position

          previous_word = ayah_words[previous_word_position[:word] - 1]

          timing = divide_segment_time(
            previous_word_position[:start_time],
            previous_word_position[:end_time],
            [previous_word[:text], word_data[:text]]
          )

          previous_word_time = timing[0]
          word_time = timing[1]

          previous_word_position[:end_time] = previous_word_time[1]

          missing_position = {
            surah: surah_number,
            ayah: ayah_number,
            word: missing_word_number,
            start_time: word_time[0],
            end_time: word_time[1],
            text: word_data[:text],
            failure_data: {
              type: 'missing_word',
              expected_text: word_data[:text]
            }
          }

          insert_index = positions.index(previous_word_position)

          if insert_index
            positions.insert(insert_index + 1, missing_position)
          else
            positions << missing_position
          end
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

    if @data.length < 10
      @data = []
    else
      @data = JSON.parse(@data)
    end
  end

  def extract_ids_from_path(file_path)
    folder_name = File.basename(File.dirname(file_path))

    # First 4 digits = reciter ID, last 4 digits = surah number
    reciter_id = folder_name[0..2].to_i
    surah_number = folder_name[3..5].to_i

    [reciter_id, surah_number]
  end

  def process_special_case(entry)
    if positions.present?
      ayah = positions.last[:ayah]
    else
      ayah = 1
    end

    text = entry['word']
    detect_word, score = detect_failure_word(text, ayah, @last_word_number || 1)

    if detect_word.present?
      entry['position'] = {
        'ayahNumber' => ayah,
        'wordNumber' => detect_word
      }

      process_position(entry)
    end
  end

  def process_position(entry)
    position_data = entry['position']

    ayah = position_data['ayahNumber']
    word_number = position_data['wordNumber']
    received_text = entry['word']

    if @last_word_number == word_number
      # Check if this is actually next word
      detect_word, score = detect_failure_word(received_text, ayah, @last_translated_word_number + 1)

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
      word = Word.find_by_location("#{surah_number}:#{ayah}:#{translated_word_number}")
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

    if !first_word_detected
      @last_word_number ||= 1
      @last_translated_word_number ||= 1
    end

    # Check if we've merged words
    @last_translated_word_number ||= translate_imlaei_word_to_uthmani(surah_number, ayah_number, @last_word_number)
    possible_word_from_received = detect_merged_word_numbers(received_text, ayah_number, @last_translated_word_number, search_radius: 3)

    if possible_word_from_received.present?
      possible_ayah_merged_words = possible_word_from_received
    else
      possible_ayah_merged_words = detect_merged_word_numbers(expected_text, ayah_number, word_index, search_radius: 2)
    end

    if possible_ayah_merged_words.blank?
      possible_ayah_merged_words = detect_merged_word_numbers(received_text, ayah_number, @last_translated_word_number + 1)
    end

    if possible_ayah_merged_words.present?
      possible_ayah_merged_words = possible_ayah_merged_words.uniq { |w| [w[:word_number], w[:ayah_number]] }

      # Split the time between the merged words
      texts = []
      possible_ayah_merged_words.each do |merged_word|
        merged_ayah, merged_word_number = [merged_word[:ayah_number], merged_word[:word_number]]
        ayah_words = get_ayah_words(surah_number, merged_ayah)
        texts << ayah_words[merged_word_number - 1][:text]
      end

      timing = divide_segment_time(start_time, end_time, texts)
      possible_ayah_merged_words.each_with_index do |merged_word, index|
        time = timing[index]

        uthmani_word = translate_uthmani_word_to_imlaei(
          merged_word[:surah_number],
          merged_word[:ayah_number],
          merged_word[:word_number]
        )

        track_position(
          ayah: merged_word[:ayah_number],
          word_number: uthmani_word.is_a?(Array) ? uthmani_word.first : uthmani_word,
          start_time: time[0],
          end_time: time[1],
          text: texts[index],
          failure_data: failure_data
        )
      end
    elsif (detect_word, _score = detect_failure_word(received_text, ayah_number, @last_translated_word_number))
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
        ].uniq,
        text: word.text_imlaei.gsub('۞', '').strip,
        word_number: word.position,
        ayah_number: ayah_number
      }
    end
  end

  def normalize_text(text)
    return '' if text.nil?
    text.tr('ًٌٍَُِّْـٰ', '')
  end

  def detect_merged_word_numbers(text, ayah_number, start_word_number, search_radius: 2)
    ayah_words = get_ayah_words(surah_number, ayah_number)
    next_ayah_words = get_ayah_words(surah_number, ayah_number + 1)
    ayah_words += next_ayah_words[0, 2] if ayah_words.size < start_word_number + 2

    normalized_target = normalize_text(text)
    # Remove consecutive duplicate letters (e.g. "اقةة" → "اقة")
    normalized_clean_target = normalized_target.gsub(/(.)\1+/, '\1')

    max_words_to_try = 3
    best_match = []
    best_match_clean = []
    min_distance = min_distance_clean = Float::INFINITY

    # Special case: repeat the starting word twice
    if start_word_number.between?(1, ayah_words.size)
      words_group = ayah_words[start_word_number - 1, 1] * 2
      best_match, min_distance = check_merged_word_combinations(
        words_group, 1, normalized_target, start_word_number, best_match, min_distance
      )
      best_match_clean, min_distance_clean = check_merged_word_combinations(
        words_group, 1, normalized_clean_target, start_word_number, best_match_clean, min_distance_clean
      )
      return filter_best_matched_ayah_words(best_match, ayah_words) if min_distance <= 3 || min_distance_clean <= 3
    end

    # Search around the start_word_number within the given radius
    (start_word_number - search_radius).upto(start_word_number + search_radius) do |pos|
      next if pos < 1 || pos > ayah_words.size

      (1..max_words_to_try).each do |count|
        words_group = ayah_words[pos - 1, count]
        next if words_group.nil? || words_group.empty?

        best_match, distance = check_merged_word_combinations(
          words_group, count, normalized_target, pos, best_match, min_distance
        )
        best_match_clean, clean_distance = check_merged_word_combinations(
          words_group, count, normalized_clean_target, pos, best_match_clean, min_distance_clean
        )

        return filter_best_matched_ayah_words(best_match, ayah_words) if distance == 0 || clean_distance == 0

        min_distance = distance if distance < min_distance
        min_distance_clean = clean_distance if clean_distance < min_distance_clean
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
        best_match = words_group.map { |w| [w[:ayah_number], w[:word_number]] }
      end

      return [best_match, 0] if distance == 0 # early exit
    end

    [best_match, min_distance]
  end

  def filter_best_matched_ayah_words(best_match, ayah_words)
    return [] if best_match.blank?

    best_match.map do |ayah_num, word_num|
      ayah_words.find { |a| a[:ayah_number] == ayah_num && a[:word_number] == word_num }
    end.compact
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

  #  search_radius: Words around expected position to check
  def detect_failure_word(text, ayah, expected_word_number, search_radius: 1)
    text = normalize_text(text)
    ayah_words = get_ayah_words(surah_number, ayah)
    next_ayah_words = get_ayah_words(surah_number, ayah + 1)
    if next_ayah_words.present? && next_ayah_words.size <= expected_word_number + 2
      ayah_words += next_ayah_words[0..2]
    end

    best_match = nil
    min_distance = Float::INFINITY

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

  def divide_segment_time(start_time, end_time, texts)
    return [[start_time, end_time]] if texts.blank? || texts.size == 1

    total_duration = end_time - start_time
    scores = texts.map { |t| calculate_word_text_score(t) }
    total_score = scores.sum

    return [[start_time, end_time]] if total_score == 0

    result = []
    current_start = start_time

    scores.each_with_index do |score, i|
      # proportion of total duration for this segment
      segment_duration = (score.to_f / total_score * total_duration).round
      segment_end = (i == scores.size - 1) ? end_time : current_start + segment_duration

      result << [current_start, segment_end]
      current_start = segment_end
    end

    result
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
