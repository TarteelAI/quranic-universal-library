class MatchingAyahService
  include Utils::StrongMemoize
  attr_reader :word_list, :base_ayah

  def initialize(verse_or_key)
    @base_ayah = load_ayah(verse_or_key)
    @word_list = base_ayah.actual_words
  end

  def find_similar_matching_phrases(min_phrase_length: 3)
    # Find phrases from other ayahs that matches with this ayah
    # Words match could be exact text match or based on same lemma or stem
    matching_ayah = {}

    MatchingAyahService.load_all_ayahs.each do |verse|
      next if verse == base_ayah
      phrases = find_matches_phrases2(verse, word_list, min_phrase_length)

      if phrases.present?
        matching_ayah[verse.verse_key] = phrases
      end
    end

    matching_ayah
  end

  def get_match_coverage(ayah)
    ayah = load_ayah(ayah)
    words = get_matching_words(ayah, use_root: true)

    ((words.size / ayah.actual_words.size.to_f) * 100).to_i
  end

  def get_longest_matching_phrase(ayah)
    ayah = load_ayah(ayah)
    base_ayah_text = tokenize_into_words(base_ayah).join(' ')
    ayah_text = tokenize_into_words(ayah).join(' ')

    longest_common_substring(base_ayah_text, ayah_text)
  end

  # Get matching words position of given ayah
  def get_matching_words(ayah, use_root: false)
    ayah = load_ayah(ayah)

    match_phrases = find_matches_phrases(ayah, phrase_length: 2, use_root: use_root)

    match_phrases.map do |match|
      range = match[:matching_range]

      (range.first..range.last).to_a
    end.flatten
  end

  # Calculate score of matched words on base ayah to given ayah
  def calculating_matching_score(ayah, avg: false, use_root: false)
    ayah = load_ayah(ayah)
    words_count = word_list.size

    match = find_matches_phrases(ayah, phrase_length: 2)
    matched_words_count = match.map do |m|
      m = m[:source_range]

      m.last - m.first + 1
    end.sum

    if avg
      score = (matched_words_count.to_f / words_count) * 60

      (score + lcs_matching_score(ayah) * 40).to_i
    else
      ((matched_words_count / words_count.to_f) * 100).to_i
    end
  end

  def lcs_matching_score(other_ayah)
    words_str1 = tokenize_into_words(base_ayah)
    words_str2 = tokenize_into_words(other_ayah)

    lcs_len = lcs_length_words(words_str1, words_str2)
    max_len = [words_str1.length, words_str2.length].max
    (lcs_len.to_f / max_len)
  end

  def find_matches_phrases(ayah, phrase_length: 3, use_root: false)
    ayah = load_ayah(ayah)

    phrases = []
    other_words = ayah.actual_words
    i = 0

    while i < word_list.length - 1
      index = i
      w = word_list[i]

      other_words.each_with_index do |w2, other_index|
        length = 0
        index_start = i
        start = other_index

        while w && w2 && (w.text_imlaei_simple == w2 || word_matched?(w, w2, use_root: use_root))
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

  #TODO: use find_matches_phrases instead of this method
  def find_matches_phrases2(ayah, word_list, min_phrase_length)
    phrases = []
    other_words = ayah.actual_words
    i = 0

    while i < word_list.length - 1
      index = i
      w = word_list[i]

      other_words.each_with_index do |w2, other_index|
        length = 0
        index_start = i
        start = other_index

        while w && w2 && (w.text_imlaei_simple == w2 || (w.word_lemma && w.word_lemma.lemma_id == w2.word_lemma&.lemma_id) || (w.word_stem && w.word_stem.stem_id == w2.word_stem&.stem_id))
          index += 1
          other_index += 1
          w = word_list[index]
          w2 = other_words[other_index]
          length += 1
        end

        if length >= min_phrase_length
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
  protected

  def word_matched?(w, w2, use_root: false)
    (w.lemma_id && w.lemma_id == w2.lemma_id) ||
      (w.stem_id && w.stem_id == w2.stem_id) ||
      (use_root && w.root_id && w.root_id == w2.root_id)
  end

  def tokenize_into_words(v)
    word_util.clean_words(v.actual_words.pluck(:text_imlaei_simple))
  end

  def lcs_length_words(x, y)
    m = x.length
    n = y.length
    lcs = Array.new(m + 1) { Array.new(n + 1, 0) }

    for i in 0..m
      for j in 0..n
        if i == 0 || j == 0
          lcs[i][j] = 0
        elsif x[i - 1] == y[j - 1]
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

    # Create a 2D array to store the lengths of common substrings
    # dp[i][j] will store the length of the common substring ending at str1[i-1] and str2[j-1]
    dp = Array.new(m + 1) { Array.new(n + 1, 0) }

    # Variables to store the length of the longest common substring and its ending position
    max_length = 0
    end_position = 0

    # Build the dp table
    for i in 1..m
      for j in 1..n
        if str1[i - 1] == str2[j - 1]
          dp[i][j] = dp[i - 1][j - 1] + 1

          # Update the length and ending position if a longer common substring is found
          if dp[i][j] > max_length
            max_length = dp[i][j]
            end_position = i - 1
          end
        else
          dp[i][j] = 0
        end
      end
    end

    # Extract the longest common substring from str1
    str1[end_position - max_length + 1..end_position]
  end

  def load_ayah(ayah_or_key)
    ayah_or_key.is_a?(Verse) ? ayah_or_key : Verse.find_by_id_or_key(ayah_or_key)
  end

  def word_util
    @word_util ||= WordsUtil.new
  end

  def self.load_all_ayahs
    @verses ||= Verse.eager_load(actual_words: [:word_lemma, :word_stem]).all
  end
end