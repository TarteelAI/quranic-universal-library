#
# a=SimilarAyahPhraseSearch.new()
# a.search_by_phrase("تَجْرِي مِن تَحْتِهَا الْأَنْهَارُ ")
# a.search_by_phrase("تَجْرِي مِن تَحْتِهَا الْأَنْهَارُ ", root: true)
# a.search_by_phrase("تَجْرِي مِن*الْأَنْهَارُ * *")
# a.search_by_phrase("ومثل ٱلذين كفروا")
# أُوْلَٰٓئِكَ ٱلَّذِينَ * ٱللَّهُ
# أُوْلَٰٓئِكَ ٱلَّذِينَ لَعَنَهُمُ ٱللَّهُ
# أُوْلَٰٓئِكَ ٱلَّذِينَ أَنۡعَمَ ٱللَّهُ
require 'diff/lcs'

class SimilarAyahPhraseSearch
  attr_accessor :phrase_text,
                :phrase,
                :phrase_simple,
                :result,
                :source_verse,
                :source_range,
                :root

  def initialize(source_verse = nil, range = nil, phrase_id = nil)
    @source_verse = source_verse
    @source_range = range
    @word_utils = WordsUtil.new
    @phrase = Morphology::Phrase.find(phrase_id) if phrase_id.present?

    @result = {}
  end

  def get_phrase(text)
    return @phrase if @phrase

    if @source_verse.present?
      if source_range.blank?
        @source_range = [1, @source_verse.words_count - 1]
      end
      text = @source_verse.words.where(position: (source_range[0]..source_range[1])).pluck(:text_qpc_hafs).join(' ')
    end

    text = text.strip

    p = Morphology::Phrase.where("text_qpc_hafs_simple = :simple OR text_qpc_hafs = :text", simple: text.remove_diacritics, text: text).first
    p || Morphology::Phrase.new(
      text_qpc_hafs_simple: text.remove_diacritics,
      text_qpc_hafs: text
    )
  end

  def get_suggestions(phrase_text = nil, text_search: true, root: false, stem: false, lemma: false, lcs: false)
    if @phrase
      @source_verse = @phrase.source_verse
      @source_range = [@phrase.word_position_from, @phrase.word_position_to]
    elsif @source_verse.present?
      if source_range.blank?
        @source_range = [1, @source_verse.words_count - 1]
      end

      phrase_text = @source_verse.words.where(position: (source_range[0]..source_range[1])).pluck(:text_qpc_hafs).join(' ')
    else
      if @source_verse = find_source_verse_using_lemma(phrase_text) || find_verse_using_text(phrase_text)
        matches = find_phrase_matches(@source_verse.text_qpc_hafs.remove_diacritics, phrase_text.remove_diacritics)

        @source_range = matches[0]
      end
    end

    if phrase_text.blank? && @source_verse.blank?
      raise "Source phrase and ayah is blank, please provide at least one source"
    end

    phrase_text = phrase_text.to_s.strip.gsub("*", "%").gsub('"', '')
    @phrase_text = phrase_text
    @phrase_simple = phrase_text.remove_diacritics(replace_hamza: false)

    search(
      text_search: text_search,
      root: root,
      stem: stem,
      lemma: lemma,
      lcs: lcs
    )
  end

  def search(text_search: true, root: false, stem: false, lemma: false, lcs: false)
    add_existing_matches

    if text_search && phrase_simple.present?
      mathced_ayah = Verse
                       .unscoped
                       .eager_load(:words)
                       .where("
    verses.text_imlaei_simple like :match_simple
    OR verses.text_imlaei_simple like :match_simple_no_tashkeel
    OR verses.text_uthmani_simple like :match_simple
    OR verses.text_uthmani_simple like :match_simple_no_tashkeel
    OR verses.text_uthmani like :tashkeel_match
    OR verses.text_indopak like :tashkeel_match
    OR verses.text_imlaei like :tashkeel_match
    OR verses.text_qpc_hafs like :tashkeel_match",
                              match_simple_no_tashkeel: "%#{phrase_simple.remove_diacritics}%",
                              match_simple: "%#{phrase_simple}%",
                              tashkeel_match: "%#{@phrase_text.strip}%"
                       ).order('verse_index asc')

      mathced_ayah.each do |ayah|
        match_indexes = find_phrase_matches(ayah.text_qpc_hafs.remove_diacritics, @phrase_text.remove_diacritics)[0]

        if match_indexes
          @result[ayah.verse_key] ||= {
            ayah: ayah,
            matcher: 'text',
            matches: []
          }

          if @result[ayah.verse_key][:matcher] != 'saved'
            range = [match_indexes[0], match_indexes[1]]
            @result[ayah.verse_key][:matches].push(range) unless @result[ayah.verse_key][:matches].include?(range)
          end
        else
          @result[ayah.verse_key] ||= {
            ayah: ayah,
            matcher: 'text',
            matches: []
          }
        end
      end
    end

    add_stem_matches if stem
    add_lemma_matches if lemma
    add_lcs_matches if lcs
    add_root_matches if root

    @result
  end

  def matches_by_surah
    Chapter.where(id: verses.pluck(:chapter_id).uniq)
  end

  def verses
    Verse.where(verse_key: @result.keys)
  end

  def roots
    Root.where id: matches_root_ids
  end

  def stems
    Stem.where id: matches_stem_ids
  end

  def lemmas
    Lemma.where id: matches_lemma_ids
  end

  def source_verse_and_range
    if @source_verse
      [@source_verse, @source_range]
    else
      first_match = @result.first[1]
      ayah = first_match[:ayah]
      matched_range = first_match[:matches].first

      [ayah, matched_range]
    end
  end

  protected

  def add_existing_matches
    p = get_phrase(@phrase_text)

    if p.persisted?
      p.phrase_verses.includes(:verse).each do |existing|
        verse_key = existing.verse.verse_key
        @result[verse_key] ||= {
          ayah: existing.verse,
          matcher: 'saved',
          matches: [],
          phrase_ayah_id: existing.id,
          skipped_words: existing.missing_word_positions
        }

        range = [existing.word_position_from, existing.word_position_to]
        @result[verse_key][:matches].push(range) unless @result[verse_key][:matches].include?(range)
      end
    end
  end

  def add_root_matches
    roots = get_roots_sequence(phrase_text)

    ids = roots.map(&:id)
    root_text = roots.map(&:text_clean).join(' ')
    verses = find_verses_by_root_sequence(root_text)

    if verses.blank?
      verses = Verse.joins(words: :word_root)
                    .where(word_roots: { root_id: ids })
                    .group('verses.id')
                    .having('array_agg(word_roots.root_id) = ARRAY[?]', ids)
    end

    verses.each do |ayah|
      range = find_phrase_matches(ayah.text_qpc_hafs.remove_diacritics, phrase_text.remove_diacritics)[0]
      range ||= find_phrase_matches(ayah.verse_root.value, root_text)[0]

      @result[ayah.verse_key] ||= {
        ayah: ayah,
        matcher: 'root',
        matches: []
      }

      if @result[ayah.verse_key][:matcher] != 'saved'
        if range.present?
          @result[ayah.verse_key][:matches].push(range) unless @result[ayah.verse_key][:matches].include?(range)
        end
      end
    end
  end

  def add_root_matches_old
    ids = matches_root_ids
    records = Verse.joins(words: :word_root)
                   .where(word_roots: { root_id: ids })
                   .group('verses.id')
                   .having('array_agg(word_roots.root_id) = ARRAY[?]', ids)

    records.each do |ayah|
      words = ayah.words.joins(:word_root).where(word_roots: { root_id: ids }).pluck :position

      @result[ayah.verse_key] ||= {
        ayah: ayah,
        matcher: 'root',
        matches: []
      }

      range = [words.min, words.max]
      @result[ayah.verse_key][:matches].push(range) unless @result[ayah.verse_key][:matches].include?(range)
    end
  end

  def add_stem_matches
    ids = matches_stem_ids
    records = Verse.joins(words: :word_stem)
                   .where(word_stems: { stem_id: ids })
                   .group('verses.id')
                   .having('array_agg(word_stems.stem_id) = ARRAY[?]', ids)

    records.each do |ayah|
      words = ayah.words.joins(:word_stem).where(word_stems: { stem_id: ids }).pluck :position

      @result[ayah.verse_key] ||= {
        ayah: ayah,
        matcher: 'stem',
        matches: []
      }

      range = [words.min, words.max]
      @result[ayah.verse_key][:matches].push(range) unless @result[ayah.verse_key][:matches].include?(range)
    end
  end

  def add_lemma_matches
    lemmas = get_lemma_sequence(phrase_text)
    #ids = lemmas.map(&:id)
    lemma_text = lemmas.map(&:text_clean).join(' ')
    verses = find_verses_by_lemma_sequence lemma_text

    if verses.blank?
      ids = matches_lemma_ids
      verses = Verse.joins(words: :word_lemma)
                    .where(word_lemmas: { lemma_id: ids })
                    .group('verses.id')
                    .having('array_agg(word_lemmas.lemma_id) = ARRAY[?]', ids)
    end

    verses.each do |ayah|
      matches = find_phrase_matches(ayah.text_qpc_hafs.remove_diacritics, phrase_text.remove_diacritics)[0]
      matches ||= find_phrase_matches(ayah.verse_lemma.text_clean, lemma_text)[0]

      #words = ayah.words.joins(:word_lemma).where(word_lemmas: { lemma_id: ids }).pluck :position

      @result[ayah.verse_key] ||= {
        ayah: ayah,
        matcher: 'lemma',
        matches: []
      }

      if @result[ayah.verse_key][:matcher] != 'saved'
        range = matches
        @result[ayah.verse_key][:matches].push(range) unless @result[ayah.verse_key][:matches].include?(range)
      end
    end
  end

  def matches_stem_ids
    ayah, matched_range = source_verse_and_range
    words = ayah.words.includes(:word_stem).where(position: matched_range.first..matched_range.last)

    words.map do |w|
      w.word_stem
    end.compact_blank.map(&:stem_id)
  end

  def add_lcs_matches
    require 'diff/lcs'

    p = phrase_text.remove_diacritics(replace_hamza: false).gsub('%', '')
    Verse.find_each do |v|
      score = calculate_lcs_similarity_ratio(phrase_text.gsub('%', ''), v.text_qpc_hafs)

      if score < 0.5
        score = calculate_lcs_similarity_ratio(p, v.text_uthmani_simple)
      end

      if score >= 0.5
        @result[v.verse_key] ||= {
          ayah: v,
          matcher: 'lcs',
          matches: []
        }

        #range = [words.min, words.max]
        #@result[ayah.verse_key][:matches].push(range) unless @result[ayah.verse_key][:matches].include?(range)
      end
    end
  end

  def calculate_lcs_similarity_ratio(text1, text2)
    sequences = Diff::LCS.sdiff(text1.split, text2.split)
    match_size = sequences.count { |change| change.action == '=' }

    if text1.split.size == match_size
      0.9 # first ayah matched entirely with the second one
    else
      total_size = [text1.split.size, text2.split.size].max.to_f
      match_size.to_f / total_size
    end
  end

  def matches_root_ids
    ayah, matched_range = source_verse_and_range
    words = ayah.words.includes(:word_root).where(position: matched_range.first..matched_range.last)

    words.map do |w|
      w.word_root
    end.compact_blank.map(&:root_id)
  end

  def matches_lemma_ids
    ayah, matched_range = source_verse_and_range
    words = ayah.words.includes(:word_lemma).where(position: matched_range.first..matched_range.last)

    words.map do |w|
      w.word_lemma
    end.compact_blank.map(&:lemma_id)
  end

  def find_matched_roots(source_roots, target_roots)
    matched = source_roots.compact & target_roots.compact

    source_roots = source_roots.compact_blank
    target_roots = target_roots.compact_blank

    i = 0
    matched_phrases = []
    group = []
    while i < source_roots.count
      w = source_roots[i]
      index = target_roots.index(w)

      if index
        group.push(w)

        i += 1
        p = index + 1

        while source_roots[i].present? && source_roots[i] == target_roots[p]
          group.push(source_roots[i])
          i += 1
          p = p + 1
        end

        if group.size >= 1
          matched_phrases.push(group)
          group = []
        end
      else
        i += 1
      end
    end

    phrase_score = matched_phrases.map do |p|
      (p.size.to_f / source_roots.size.to_f)
    end.sum

    [phrase_score, matched_phrases]
  end

  def find_match_words_range_using_lcs(ayah_text, sub_text)
    big_array = ayah_text.split(' ')
    small_array = sub_text.split(' ')

    sequences = Diff::LCS.sdiff(small_array, big_array)
    start_index = nil
    end_index = nil

    sequences.each do |change|
      index = change.new_position
      case change.action
      when '='
        if start_index.nil?
          start_index = index
          end_index = index
        elsif index > end_index
          end_index = index
        end
      when '!'
        if start_index.present?
          end_index = index
        end
      when '-'
        if change.old_element == '*' || change.old_element == '*'
          end_index = index
        else
          break if start_index.present?
        end
      end
    end

    [start_index, end_index] if start_index && end_index
  end

  def find_phrase_matches(ayah_text, phrase_text)
    ayah_text = @word_utils.remove_waqf(ayah_text).split(/\s/)
    phrase_text = @word_utils.remove_waqf(phrase_text).split(/\s/)
    matches = []

    ayah_text.each_with_index do |text, index|
      match_size = 0

      phrase_text.each_with_index do |phrase_word, phrase_index|
        break unless ayah_text[index + phrase_index] == phrase_word

        match_size += 1
      end

      if match_size > 0
        # we need word position, not array index which starts at 0
        matches << [index + 1, index + match_size]
      end
    end

    matches.sort_by { |range| range.last - range.first }.reverse
  end

  def find_indices(ayah_text, sub_text)
    big_array = ayah_text.split(' ')
    small_array = sub_text.split(' ')

    start_index = big_array.each_cons(small_array.length).find_index { |chunk| chunk == small_array }

    if start_index
      end_index = start_index + small_array.length - 1

      [start_index, end_index]
    end
  end

  def find_verses_by_lemma_sequence(lemma_text)
    Verse.joins(:verse_lemma).where("verse_lemmas.text_clean like ?", "%#{lemma_text}%")
  end

  def find_verses_by_root_sequence(root_text)
    Verse.joins(:verse_root).where("verse_roots.value like ?", "%#{root_text}%")
  end

  def get_roots_sequence(text)
    find_words_sequence(text, :root).map do |w|
      w.root
    end.compact
  end

  def get_lemma_sequence(text)
    find_words_sequence(text, :lemma).map do |w|
      w.lemma
    end.compact
  end

  def find_words_sequence(text, eager_load = nil)
    text = @word_utils.remove_waqf(text)

    text.split(/\s/).map do |w|
      word = Word.eager_load(eager_load).where("words.text_uthmani = :tashkeel OR text_indopak = :tashkeel OR text_qpc_hafs = :tashkeel OR text_indopak_nastaleeq = :tashkeel OR  text_imlaei = :tashkeel OR text_uthmani_simple = :simple OR text_imlaei_simple = :simple", tashkeel: w, simple: w.remove_diacritics).first
      word ||= Word.eager_load(eager_load).where("words.text_uthmani ilike :tashkeel OR text_indopak ilike :tashkeel OR text_qpc_hafs ilike :tashkeel OR text_indopak_nastaleeq ilike :tashkeel OR  text_imlaei ilike :tashkeel OR text_uthmani_simple ilike :simple OR  text_imlaei_simple ilike :simple", tashkeel: "%#{w}", simple: "%#{w.remove_diacritics}").first

      word || Word.eager_load(eager_load).where(
        "REPLACE(words.text_uthmani, 'ـ', '') ilike :tashkeel OR REPLACE(text_indopak, 'ـ', '') ilike :tashkeel OR REPLACE(text_qpc_hafs, 'ـ', '') ilike :tashkeel OR REPLACE(text_indopak_nastaleeq, 'ـ', '') ilike :tashkeel OR REPLACE(text_imlaei, 'ـ', '') ilike :tashkeel OR REPLACE(text_uthmani_simple, 'ـ', '') ilike :simple OR REPLACE(text_imlaei_simple, 'ـ', '') ilike :simple",
        tashkeel: "%#{w}%",
        simple: "%#{w.remove_diacritics}%"
      ).first
    end
  end

  def find_verse_using_text(text)
    w = text
    verse = Verse.where("text_uthmani = :tashkeel OR text_indopak = :tashkeel OR text_qpc_hafs = :tashkeel OR text_indopak_nastaleeq = :tashkeel OR  text_imlaei = :tashkeel OR text_uthmani_simple = :simple OR text_imlaei_simple = :simple", tashkeel: w, simple: w.remove_diacritics).first
    verse ||= Verse.where("text_uthmani ilike :tashkeel OR text_indopak ilike :tashkeel OR text_qpc_hafs ilike :tashkeel OR text_indopak_nastaleeq ilike :tashkeel OR  text_imlaei ilike :tashkeel OR text_uthmani_simple ilike :simple OR  text_imlaei_simple ilike :simple", tashkeel: "%#{w}", simple: "%#{w.remove_diacritics}").first
    verse || Verse.where(
      "REPLACE(text_uthmani, 'ـ', '') ilike :tashkeel OR REPLACE(text_indopak, 'ـ', '') ilike :tashkeel OR REPLACE(text_qpc_hafs, 'ـ', '') ilike :tashkeel OR REPLACE(text_indopak_nastaleeq, 'ـ', '') ilike :tashkeel OR REPLACE(text_imlaei, 'ـ', '') ilike :tashkeel OR REPLACE(text_uthmani_simple, 'ـ', '') ilike :simple OR REPLACE(text_imlaei_simple, 'ـ', '') ilike :simple",
      tashkeel: "%#{w}%",
      simple: "%#{w.remove_diacritics}%"
    ).first
  end

  def find_source_verse_using_lemma(text)
    lemma = get_lemma_sequence(text).map(&:text_clean)
    find_verses_by_lemma_sequence(lemma.join(' ')).first
  end
end