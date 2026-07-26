class WordTranslationsPresenter < ApplicationPresenter
  LANGUAGE_BADGE_CLASSES = [
    "bg-red-100 text-red-800 ring-red-200",
    "bg-orange-100 text-orange-800 ring-orange-200",
    "bg-amber-100 text-amber-800 ring-amber-200",
    "bg-yellow-100 text-yellow-800 ring-yellow-200",
    "bg-lime-100 text-lime-800 ring-lime-200",
    "bg-green-100 text-green-800 ring-green-200",
    "bg-emerald-100 text-emerald-800 ring-emerald-200",
    "bg-teal-100 text-teal-800 ring-teal-200",
    "bg-cyan-100 text-cyan-800 ring-cyan-200",
    "bg-sky-100 text-sky-800 ring-sky-200",
    "bg-blue-100 text-blue-800 ring-blue-200",
    "bg-indigo-100 text-indigo-800 ring-indigo-200",
    "bg-violet-100 text-violet-800 ring-violet-200",
    "bg-purple-100 text-purple-800 ring-purple-200",
    "bg-pink-100 text-pink-800 ring-pink-200",
    "bg-rose-100 text-rose-800 ring-rose-200"
  ].freeze

  def meta_title
    "Word by Word Translation Editor"
  end

  def meta_description
    "Refine and review word by word translations of the Quran in various languages. Correct OCR mistakes, typos, and improve clarity for better understanding and precision."
  end

  def meta_keywords
    'Quran Unicode characters, Arabic letter details, Quran text debugging, Arabic character codes, Unicode values of Quranic letters, Arabic font issues, Quran font troubleshooting, inspect Arabic text unicode, Quran corpus letter info, Arabic script technical analysis'
  end

  def resource
    return @resource if @resource_loaded

    @resource_loaded = true
    @resource = if params[:resource_id].present?
                  ResourceContent.translations.one_word.find_by(id: params[:resource_id])
                end
  end

  def resources
    @resources ||= ResourceContent.translations.one_word.includes(:language).order('language_name asc, name asc')
  end

  def language
    resource&.language
  end

  def language_class
    "#{language&.iso_code} #{language&.name&.downcase}"
  end

  def english?
    language&.english?
  end

  def total_words
    @total_words ||= Word.words.count
  end

  def language_badge_class(name)
    LANGUAGE_BADGE_CLASSES[name.to_s.hash.abs % LANGUAGE_BADGE_CLASSES.size]
  end

  # Distinct translated word counts for every resource, keyed by resource id.
  def translated_counts
    @translated_counts ||= WordTranslation
                             .joins(:word)
                             .where(resource_content_id: resources.map(&:id), words: { char_type_id: 1 })
                             .where.not(text: [nil, ''])
                             .group(:resource_content_id)
                             .distinct
                             .count(:word_id)
  end

  def resource_stats(res)
    stats_for(translated_counts[res.id] || 0)
  end

  # Coverage for the currently selected resource.
  def coverage_stats
    @coverage_stats ||= stats_for(resource_translated_count)
  end

  def verses
    list = Verse
    list = list.where(juz_number: params[:filter_juz].to_i) if params[:filter_juz].to_i > 0
    list = list.where(chapter_id: params[:filter_chapter].to_i) if params[:filter_chapter].to_i > 0
    list = list.where(verse_number: params[:verse_number].to_i) if params[:verse_number].to_i > 0
    list = list.verses_with_missing_translations(resource.id) if params[:filter_missing] == 'true'

    paginate(list.order("verse_index #{sort_order}"))
  end

  def verse_progress(verse)
    verse.word_translation_progress(resource.id)
  end

  # Progress percentage for many verses using two queries instead of two per verse.
  def verse_progress_map(verses)
    verse_ids = verses.map(&:id)
    return {} if verse_ids.empty?

    totals = Word.words.where(verse_id: verse_ids).reorder(nil).group(:verse_id).count
    translated = WordTranslation
                   .joins(:word)
                   .where(resource_content_id: resource.id, words: { char_type_id: 1, verse_id: verse_ids })
                   .where.not(text: [nil, ''])
                   .reorder(nil)
                   .group('words.verse_id')
                   .distinct
                   .count(:word_id)

    verse_ids.index_with do |verse_id|
      total = totals[verse_id].to_i
      done = translated[verse_id].to_i
      total > 0 ? (done * 100.0 / total).floor.clamp(0, 100) : 0
    end
  end

  def verse_words(verse)
    @verse_words ||= {}
    @verse_words[verse.id] ||= verse.words.includes(:en_translation).order('position ASC')
  end

  def translations_by_word(verse)
    @translations_by_word ||= {}
    @translations_by_word[verse.id] ||= WordTranslation
                                          .where(resource_content_id: resource.id, word_id: verse_words(verse).map(&:id))
                                          .includes(:group_word)
                                          .order(Arel.sql("(text IS NOT NULL AND text <> '') ASC"))
                                          .index_by(&:word_id)
  end

  def has_group_translation?(verse)
    translations_by_word(verse).values.any? { |t| t.group_word_id.present? }
  end

  def wbw_translations(verse)
    words = verse.words.words.includes(:en_translation).order('position asc')
    existing = WordTranslation
                 .where(resource_content_id: resource.id, word_id: words.map(&:id))
                 .index_by(&:word_id)

    words.map do |word|
      word_translation = existing[word.id] ||
                         WordTranslation.new(word_id: word.id, resource_content_id: resource.id, language_id: resource.language_id)
      word_translation.word = word
      word_translation
    end
  end

  def group_word_translation(word_id)
    word_translation = WordTranslation
                         .where(word_id: word_id, resource_content_id: resource.id)
                         .first_or_initialize
    word_translation.language_id ||= resource.language_id
    word_translation
  end

  private

  def resource_translated_count
    WordTranslation
      .joins(:word)
      .where(resource_content_id: resource.id, words: { char_type_id: 1 })
      .where.not(text: [nil, ''])
      .distinct
      .count(:word_id)
  end

  def stats_for(translated)
    missing = [total_words - translated, 0].max

    progress = if total_words.zero?
                 0
               elsif missing.zero?
                 100
               else
                 [(translated * 100.0 / total_words).floor, 99].min
               end

    {
      total: total_words,
      translated: translated,
      missing: missing,
      progress: progress
    }
  end
end
