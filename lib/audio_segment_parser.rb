require 'json'
require 'oj'

=begin
file_path = '/Volumes/Data/qul-segments/aug-6/vs_logs/00020002-d6ca-4db1-962e-fb91c3889f10/time-machine.json'
file_path = '/Volumes/Data/qul-segments/aug-6/vs_logs/00020001-960f-4405-914f-becca3d8f93f/time-machine.json'

parser = AudioSegmentParser.new(file_path)
parser.run
=end

class AudioSegmentParser
  MUSHAF_TRANSLATOR_INDEX = Oj.load(File.read("lib/data/mushaf-translator-index.json"))

  attr_reader :file_path,
              :reciter_id,
              :surah_number,
              :positions,
              :failures,
              :last_word_number,
              :last_translated_word_number,
              :first_ayah_detected

  def initialize(file_path)
    @file_path = file_path
    @reciter_id, @surah_number = extract_ids_from_path(file_path)
    @positions = []
    @failures = []
    @last_word_number = nil
    @last_translated_word_number = nil
    @first_ayah_detected = false
  end

  def run
    data = File.read(file_path)
    return if data.length < 10 # Skip empty or too short files
    data = JSON.parse(data)

      data.each do |entry|
        case entry['type']
        when 'POSITION'
          process_position(entry)
        when 'FAILURE'
          process_failure(entry)
        end
      end
      
      # Fix any missing positions after processing all entries
      fix_missing_positions
    rescue => e
      puts "Error processing file #{file_path}: #{e.message}"
      puts e.backtrace.first(3).join("\n  ")
    end

  def fix_missing_positions
    # Group positions by ayah to check for missing words
    positions_by_ayah = positions.group_by { |pos| pos[:ayah] }
    
    positions_by_ayah.each do |ayah_number, ayah_positions|
      # Get the expected words for this ayah
      expected_words = get_ayah_words(surah_number, ayah_number)
      next if expected_words.empty?
      
      # Sort positions by word number to maintain order
      ayah_positions.sort_by! { |pos| pos[:word] }
      
      # Check for missing words
      expected_word_numbers = (1..expected_words.length).to_a
      existing_word_numbers = ayah_positions.map { |pos| pos[:word] }
      missing_word_numbers = expected_word_numbers - existing_word_numbers
      
      next if missing_word_numbers.empty?
      
      # Find the last word position in this ayah to split time from
      last_word_position = ayah_positions.max_by { |pos| pos[:word] }
      next unless last_word_position
      
      # For each missing word, create a position by splitting time
      missing_word_numbers.each do |missing_word_number|
        # Get the word text for the missing position
        word_data = expected_words[missing_word_number - 1]
        next unless word_data
        
        # Use the first available text variation
        word_text = word_data[:texts]&.first || word_data[:text]
        next unless word_text
        
        # Calculate time split - distribute missing words evenly across the last word's duration
        missing_count = missing_word_numbers.length
        total_duration = last_word_position[:end_time] - last_word_position[:start_time]
        
        # Calculate start and end time for this missing word
        time_per_word = total_duration / (missing_count + 1) # +1 for the last word itself
        word_start_time = last_word_position[:start_time] + (time_per_word * (missing_word_numbers.index(missing_word_number) + 1))
        word_end_time = word_start_time + time_per_word
        
        # Adjust the last word's end time to make room for missing words
        if missing_word_numbers.index(missing_word_number) == 0
          last_word_position[:end_time] = word_start_time
        end
        
        # Create the missing position
        missing_position = {
          surah: surah_number,
          ayah: ayah_number,
          word: missing_word_number,
          start_time: word_start_time,
          end_time: word_end_time,
          text: word_text,
          failure_data: {
            type: 'interpolated',
            reason: 'missing_position_filled'
          }
        }
        
        # Insert the missing position in the correct order
        insert_index = positions.index { |pos| pos[:ayah] == ayah_number && pos[:word] > missing_word_number }
        if insert_index
          positions.insert(insert_index, missing_position)
        else
          positions << missing_position
        end
        
        # Update the last word number tracking if needed
        if missing_word_number > @last_word_number.to_i
          @last_word_number = missing_word_number
          @last_translated_word_number = translate_imlaei_word_to_uthmani(surah_number, ayah_number, missing_word_number)
        end
      end
    end
    
    # Sort all positions by ayah and word number
    positions.sort_by! { |pos| [pos[:ayah], pos[:word]] }
  end

  private

  def extract_ids_from_path(file_path)
    # Extract folder name from path (e.g., "00020002-d6ca-4db1-962e-fb91c3889f10")
    folder_name = File.basename(File.dirname(file_path))

    # First 4 digits = reciter ID, last 4 digits = surah number
    reciter_id = folder_name[0..3].to_i
    surah_number = folder_name[4..7].to_i

    [reciter_id, surah_number]
  end

  def process_position(entry)
    position_data = entry['position']

    ayah = position_data['ayahNumber']
    word_number = position_data['wordNumber']

    track_position(
      ayah: ayah,
      word_number: word_number,
      start_time: entry['startTime'],
      text: entry['word'],
      end_time: entry['endTime']
    )
  end

  def track_position(ayah:, word_number:, start_time:, end_time:, text:, failure_data: {})
    translated_word_number = translate_imlaei_word_to_uthmani(surah_number, ayah, word_number)

    if !first_ayah_detected || ayah.to_i == 1
      @first_ayah_detected = true

      verse = Verse.where(chapter_id: surah_number, verse_number: 1).first
      if verse.has_harooq_muqattaat? && word_number.to_i > 1
        ayah = 1
        word_number = 1
        translated_word_number = 1
      end
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

    word = Word.find_by_location("#{surah_number}:#{ayah}:#{translated_word_number}")
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

    failure_data = {
      expected_text: expected_text,
      received_text: received_text,
      ayah_number: ayah_number,
      type: mistake['mistakeType']
    }

    # Check if we've merged words
    possible_ayah_merged_words = detect_merged_word_numbers(received_text, ayah_number, last_translated_word_number)

    if possible_ayah_merged_words.blank?
      begin
        possible_ayah_merged_words = detect_merged_word_numbers(received_text, ayah_number, last_translated_word_number + 1)
      rescue => e
      end
    end

    binding.pry if entry['word'] == "وَلَالِّينْ"

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

        binding.pry if first_word_text.nil? || second_word_text.nil?

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
    elsif detect_word = detect_failure_word(expected_text, ayah_number, last_translated_word_number)
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
      binding.pry if @debugg.nil?
    end

    # detect_word = detect_failure_word(expected_text, ayah_number, last_translated_word_number)
    # word, distance = detect_failure_word(received_text, ayah_number, last_translated_word_number)
    # failure_type = detect_failure_type(entry)

    # corrected_word_number = auto_fix_and_process_failure(entry, expected_word_number)
  end

  def auto_fix_and_process_failure(entry, original_word_number)
    mistake = entry['mistakeWithPositions']
    return original_word_number unless mistake

    corrected_word_number = auto_fix_failure(entry, original_word_number)

    # Detect the specific failure type
    detected_failure_type = detect_failure_type(entry)

    # Save the corrected failure
    position_data = mistake['positions'].first
    Segments::Failure.create!(
      surah_number: position_data['surahNumber'],
      ayah_number: position_data['ayahNumber'],
      word_number: original_word_number,
      word_key: generate_word_key(position_data['surahNumber'], position_data['ayahNumber'], original_word_number),
      reciter_id: reciter_id,
      failure_type: detected_failure_type || mistake['mistakeType'],
      received_transcript: entry['word'],
      expected_transcript: mistake['expectedTranscript'],
      start_time: entry['startTime'],
      end_time: entry['endTime'],
      mistake_positions: mistake['positions'].to_json,
      corrected: corrected_word_number != original_word_number,
      corrected_word_number: corrected_word_number,
      corrected_start_time: entry['startTime'],
      corrected_end_time: entry['endTime']
    )

    corrected_word_number
  end

  def auto_fix_failure(entry, original_word_number)
    mistake = entry['mistakeWithPositions']
    return original_word_number unless mistake

    received_text = normalize_text(entry['word'])
    expected_text = normalize_text(mistake['expectedTranscript'])

    # Get ayah words for comparison
    ayah_words = get_ayah_words(mistake['positions'].first['surahNumber'], mistake['positions'].first['ayahNumber'])

    # Find best match using Levenshtein distance
    best_match = find_best_word_match(received_text, expected_text, ayah_words, original_word_number)

    best_match || original_word_number
  end

  def find_best_word_match(received_text, expected_text, ayah_words, original_word_number)
    best_match = nil
    min_distance = Float::INFINITY
    search_radius = 2 # Words around expected position to check

    # Calculate search range
    start_index = [0, original_word_number - search_radius - 1].max
    end_index = [ayah_words.length - 1, original_word_number + search_radius - 1].min

    (start_index..end_index).each do |idx|
      word_data = ayah_words[idx]
      next unless word_data

      # Check each possible text variation for the word
      word_texts = word_data[:texts] || [word_data[:text]]

      word_texts.each do |word_text|
        normalized_word_text = normalize_text(word_text)

        # Calculate distances
        received_distance = levenshtein_distance(received_text, normalized_word_text)
        expected_distance = levenshtein_distance(expected_text, normalized_word_text)

        # Prioritize exact matches
        if received_distance == 0 || expected_distance == 0
          return word_data[:word_number]
        end

        # Use combined distance for ranking
        combined_distance = [received_distance, expected_distance].min

        if combined_distance < min_distance
          min_distance = combined_distance
          best_match = word_data[:word_number]
        end
      end
    end

    best_match
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

    max_words_to_try = 3
    best_match = []
    min_distance = Float::INFINITY

    # Special case: repeat first word twice
    words_group = ayah_words[start_word_number - 1, 1] * 2
    best_match, min_distance = check_merged_word_combinations(words_group, 1, normalized_target, start_word_number, best_match, min_distance)
    return best_match if min_distance == 0
    return best_match if min_distance <= 3

    # Try 2..max_words_to_try combinations
    (2..max_words_to_try).each do |count|
      words_group = ayah_words[start_word_number - 1, count]
      best_match, min_distance = check_merged_word_combinations(words_group, count, normalized_target, start_word_number, best_match, min_distance)
      return best_match if min_distance == 0
    end

    min_distance <= 3 ? best_match : []
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
        imlaei_entry[1].to_i == 0 ? [1, imlaei_entry.first.to_i + 1] : uthmani_word
      end
    else
      uthmani_word
    end
  end

  def generate_word_key(surah_number, ayah_number, word_number)
    "#{surah_number}:#{ayah_number}:#{word_number}"
  end

  def detect_failure_type(entry)
    mistake = entry['mistakeWithPositions']
    return nil unless mistake

    received_text = entry['word']
    expected_text = mistake['expectedTranscript']

    # Normalize texts for comparison
    normalized_received = normalize_text(received_text)
    normalized_expected = normalize_text(expected_text)

    if extra_word?(normalized_received, normalized_expected)
      return 'extra_word'
    end

    # Check for repeat_word: received text is completely different from expected
    if repeat_word?(normalized_received, normalized_expected)
      return 'repeat_word'
    end

    # Check for merged_words: received text is significantly longer and contains expected text
    if merged_words?(normalized_received, normalized_expected)
      return 'merged_words'
    end
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
          return word_data[:word_number]
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

  def merged_words?(received_text, expected_text)
    # Check if received text is significantly longer and contains the expected text
    return false if received_text.length <= expected_text.length

    # Check if expected text is a substring of received text
    received_text.include?(expected_text)
  end

  def extra_word?(received_text, expected_text) end

  def repeat_word?(received_text, expected_text)
    # Check if received text is completely different from expected
    # and not significantly longer (ruling out merged_words and extra_word)

    # If texts are very different and similar in length
    if received_text != expected_text &&
      (received_text.length - expected_text.length).abs <= 2
      return true
    end

    # If received text is shorter but completely different
    if received_text.length < expected_text.length &&
      !expected_text.include?(received_text) &&
      !received_text.include?(expected_text)
      return true
    end

    false
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
