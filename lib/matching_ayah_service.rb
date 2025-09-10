class MatchingAyahService
  include Utils::StrongMemoize
  attr_reader :word_list, :base_ayah

  def initialize(verse_or_key)
    @base_ayah = load_ayah(verse_or_key)
    @word_list = base_ayah.actual_words
  end

  def find_similar_matching_phrases(min_phrase_length: 3)
    matching_ayah = {}

    MatchingAyahService.load_all_ayahs.each do |verse|
      next if verse == base_ayah

      phrases = find_matching_phrases(verse, phrase_length: min_phrase_length)
      matching_ayah[verse.verse_key] = phrases if phrases.present?
    end

    matching_ayah
  end

  def get_match_coverage(ayah)
    ayah = load_ayah(ayah)
    matching_words = get_matching_words(ayah, use_root: true)

    return 0 if ayah.actual_words.empty?

    coverage = (matching_words.size.to_f / ayah.actual_words.size) * 100
    coverage.round
  end

  def get_matching_score(ayah, use_root: false)
    ayah = load_ayah(ayah)
    return 0 if word_list.empty?

    match_phrases = find_matching_phrases(ayah, phrase_length: 2, use_root: use_root)
    matched_words_count = calculate_matched_words_count(match_phrases)

    ((matched_words_count.to_f / word_list.size) * 100).round
  end

  def get_comprehensive_score(ayah, use_root: false)
    ayah = load_ayah(ayah)
    return 0 if word_list.empty?

    match_phrases = find_matching_phrases(ayah, phrase_length: 2, use_root: use_root)
    matched_words_count = calculate_matched_words_count(match_phrases)

    word_score = (matched_words_count.to_f / word_list.size) * 60
    lcs_score = lcs_matching_score(ayah) * 40

    (word_score + lcs_score).round
  end

  def get_longest_matching_phrase(ayah)
    ayah = load_ayah(ayah)
    base_text = tokenize_into_words(base_ayah).join(' ')
    ayah_text = tokenize_into_words(ayah).join(' ')

    longest_common_substring(base_text, ayah_text)
  end

  def get_matching_words(ayah, use_root: false)
    ayah = load_ayah(ayah)
    match_phrases = find_matching_phrases(ayah, phrase_length: 2, use_root: use_root)

    match_phrases.flat_map do |match|
      range = match[:matching_range]
      (range.first..range.last).to_a
    end
  end

  def find_matching_phrases(ayah, phrase_length: 3, use_root: false)
    ayah = load_ayah(ayah)
    other_words = ayah.actual_words
    phrases = []
    i = 0

    while i < word_list.length - 1
      index = i
      w = word_list[i]

      other_words.each_with_index do |w2, other_index|
        length = 0
        index_start = i
        start = other_index

        while w && w2 && words_match?(w, w2, use_root: use_root)
          index += 1
          other_index += 1
          w = word_list[index]
          w2 = other_words[other_index]
          length += 1
        end

        if length >= phrase_length
          phrases.push(
            {
              source_range: [index_start + 1, index],
              matching_range: [start + 1, other_index],
              text: other_words[start..other_index - 1].map(&:text_qpc_hafs).join(' ')
            }
          )

          i = index
        end
      end

      i = i < index ? index : i + 1
    end

    phrases
  end

  private

  def words_match?(w1, w2, use_root: false)
    return false unless w1 && w2

    (w1.text_imlaei_simple == w2.text_imlaei_simple) ||
      (w1.lemma_id && w1.lemma_id == w2.lemma_id) ||
      (w1.stem_id && w1.stem_id == w2.stem_id) ||
      (use_root && w1.root_id && w1.root_id == w2.root_id)
  end

  def calculate_matched_words_count(match_phrases)
    match_phrases.sum do |match|
      range = match[:source_range]
      range.last - range.first + 1
    end
  end

  def tokenize_into_words(verse)
    word_util.clean_words(verse.actual_words.pluck(:text_imlaei_simple))
  end

  def lcs_matching_score(other_ayah)
    words_str1 = tokenize_into_words(base_ayah)
    words_str2 = tokenize_into_words(other_ayah)

    return 0 if words_str1.empty? || words_str2.empty?

    lcs_len = lcs_length_words(words_str1, words_str2)
    max_len = [words_str1.length, words_str2.length].max
    (lcs_len.to_f / max_len).round(2)
  end

  def lcs_length_words(x, y)
    m = x.length
    n = y.length
    lcs = Array.new(m + 1) { Array.new(n + 1, 0) }

    (1..m).each do |i|
      (1..n).each do |j|
        if x[i - 1] == y[j - 1]
          lcs[i][j] = lcs[i - 1][j - 1] + 1
        else
          lcs[i][j] = [lcs[i - 1][j], lcs[i][j - 1]].max
        end
      end
    end

    lcs[m][n]
  end

  def longest_common_substring(str1, str2)
    m = str1.length
    n = str2.length
    dp = Array.new(m + 1) { Array.new(n + 1, 0) }
    max_length = 0
    end_position = 0

    (1..m).each do |i|
      (1..n).each do |j|
        if str1[i - 1] == str2[j - 1]
          dp[i][j] = dp[i - 1][j - 1] + 1

          if dp[i][j] > max_length
            max_length = dp[i][j]
            end_position = i - 1
          end
        end
      end
    end

    max_length > 0 ? str1[end_position - max_length + 1..end_position] : ""
  end

  def load_ayah(ayah_or_key)
    ayah_or_key.is_a?(Verse) ? ayah_or_key : Verse.find_by_id_or_key(ayah_or_key)
  end

  def word_util
    @word_util ||= WordsUtil.new
  end

  def self.load_all_ayahs
    @verses ||= Verse.includes(:actual_words).all
  end
end
