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
