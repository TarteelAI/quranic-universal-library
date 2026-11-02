class WordRootsPresenter < ApplicationPresenter
  def verses
    list = Verse.all
    list = list.where(chapter_id: params[:filter_chapter].to_i) if params[:filter_chapter].to_i > 0
    list = list.where(verse_number: params[:verse_number].to_i) if params[:verse_number].to_i > 0

    paginate(list.order(verse_index: sort_order))
  end

  def verse
    @verse ||= Verse.find(params[:id])
  end

  def words
    @words ||= verse.words.words.includes(:root, :stem, :lemma).order(:position).to_a
  end

  # { word_id => English translation }
  def translations
    @translations ||= WordTranslation.where(word_id: words.map(&:id), language_id: 38).pluck(:word_id, :text).to_h
  end

  # Matches for the root, stem or lemma select, the value is the text that's saved
  def link_options(type, query)
    query = query.to_s.strip
    clean = query.remove(/[\u064B-\u065F\u0670\u06D6-\u06ED\s]/)

    case type
    when 'root'
      list = Root.order(words_count: :desc).limit(20)
      if query.present?
        letters = clean.chars.join(' ')
        list = list.where('arabic_trilateral LIKE :letters OR english_trilateral = :query OR en_translations::text ILIKE :meaning',
                          letters: "#{letters}%", query: query, meaning: "%#{Root.sanitize_sql_like(query)}%")
      end
      list.map { |root| { id: root.arabic_trilateral, text: root.arabic_trilateral, meaning: [root.english_trilateral, root.english_translations.first].compact_blank.join(' · ') } }
    when 'stem', 'lemma'
      model = type == 'stem' ? Stem : Lemma
      list = model.order(words_count: :desc).limit(20)
      list = list.where('text_clean LIKE ?', "#{model.sanitize_sql_like(clean)}%") if clean.present?
      list.map do |record|
        { id: record.text_madani, text: record.text_madani, meaning: Array(record.try(:en_translations)).first }
      end
    else
      []
    end
  end

  def pending_suggestions
    Draft::WordRoot.pending_contributions.where(verse_id: verse.id).order(:created_at)
  end

  def page_title
    case action_name
    when 'show'
      "Roots, stems and lemmas of #{verse.verse_key}"
    when 'edit', 'update'
      "Suggest a fix: roots, stems and lemmas of #{verse.verse_key}"
    else
      'Word roots, stems and lemmas'
    end
  end

  def meta_title
    page_title
  end

  def meta_description
    'Proofread and suggest fixes for the root, stem and lemma of each Quran word.'
  end
end
