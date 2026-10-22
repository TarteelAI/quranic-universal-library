class MorphologyPhrasesPresenter < ApplicationPresenter
  STATS_SORT_KEYS = %w[phrases linked_ayahs words_covered status].freeze
  STATUS_ORDER = { needs_review: 0, reviewed: 1, none: 2 }.freeze
  def meta_title
    "Mutashabihat ul Quran"
  end

  def meta_description
    "Use the Mutashabihat ul Quran tool to discover, compare, and contribute similar or repeated verses and phrases across the Quran. Filter by Surah or Ayah, search content, and help build an accurate repository of mutashabihat for deeper study."
  end

  def verse
    return @verse if defined?(@verse)

    @verse = Verse.find_by_id_or_key(params[:id])
  end

  def phrase
    @phrase ||= Morphology::Phrase.find(params[:id])
  end

  # Source phrase and the ayahs sharing it, for the phrase builder.
  # nil when the requested ayah or typed phrase can't be found.
  def review
    return @review if defined?(@review)

    @review = if show?
                Mutashabihat::PhraseReview.for_phrase(phrase)
              else
                Mutashabihat::PhraseReview.for_params(
                  ayah_key: params[:ayah_key].presence || params[:source_ayah],
                  word_from: params[:word_from],
                  word_to: params[:word_to],
                  text: params[:text]
                )
              end
  end

  # Shared phrases auto-detected in the ayah
  def detected_phrases
    @detected_phrases ||= Mutashabihat::Detector.new.auto_detect(verse)
  end

  # Saved phrases of the ayah, grouped for the ayah proofreading page
  def ayah_overview
    @ayah_overview ||= Mutashabihat::AyahOverview.new(verse)
  end

  # Groups of duplicate phrases among the ayah's phrases, keeper first
  def duplicate_groups
    @duplicate_groups ||= Mutashabihat::DuplicatePhrases.new(phrase_ids: ayah_overview.groups.map { |g| g.phrase.id }).groups
  end

  # Ayahs for the proofreading list, narrowed by params[:status]
  def proofread_verses
    list = Verse
    list = list.where(chapter_id: params[:filter_chapter]) if params[:filter_chapter].present?
    list = list.where(verse_number: params[:verse_number]) if params[:verse_number].present?

    ids = Mutashabihat::AyahOverview.verse_ids_for(params[:status])
    if ids
      list = params[:status] == 'without_phrases' ? list.where.not(id: ids) : list.where(id: ids)
    end

    list
  end

  # Ids of the listed ayahs sorted by one of their phrase stats, ties in
  # mushaf order
  def sorted_verse_ids(list, key, order)
    verses = list.select(:id, :words_count, :verse_index).to_a
    stats = Mutashabihat::AyahOverview.stats_for(verses)

    value = lambda do |s|
      case key
      when 'phrases' then s.phrases_count
      when 'linked_ayahs' then s.linked_ayahs_count
      when 'words_covered' then s.words_count.positive? ? s.covered_words.to_f / s.words_count : 0
      when 'status' then STATUS_ORDER[s.status]
      end
    end

    direction = order == 'desc' ? -1 : 1
    verses.sort_by { |v| [direction * value.call(stats[v.id]), v.verse_index] }.map(&:id)
  end

  # verse_id => phrase counts, for the ayahs on the current page
  def ayah_stats(verses)
    @ayah_stats ||= Mutashabihat::AyahOverview.stats_for(verses)
  end

  # Ayahs of a phrase with the ranges saved for each, for the expandable
  # ayah list on the ayah page
  def phrase_ayah_rows
    @phrase_ayah_rows ||= begin
      rows = phrase.phrase_verses.not_removed.order(:verse_id, :word_position_from).to_a
      verses = Verse.includes(:words).where(id: rows.map(&:verse_id).uniq).index_by(&:id)
      rows.each { |r| r.verse = verses[r.verse_id] }
    end
  end

  def meta_keywords
    'Mutashabihat ul Quran, similar Quran verses, Quran phrase matching, mutashabihat builder, contribute Quran data, Quran morphology tool, explore repeated Ayah'
  end
end
