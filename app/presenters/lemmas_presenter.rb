class LemmasPresenter < ApplicationPresenter
  def lemmas
    list = Lemma.all
    list = list.where("en_translations = '[]'::jsonb") if params[:missing] == 'en_meanings'

    if params[:query].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query].strip)}%"
      list = list.where('text_clean ILIKE :query OR text_madani ILIKE :query OR en_translations::text ILIKE :query', query: query)
    end

    paginate(list.order(words_count: :desc, id: :asc))
  end

  def lemma
    @lemma ||= Lemma.find(params[:id])
  end

  # Each word with this lemma, most used first
  def word_forms
    Word.unscoped
        .left_joins(:word_translation)
        .where(lemma_id: lemma.id)
        .where('word_translations.language_id = 38 OR word_translations.id IS NULL')
        .select(
          'words.text_qpc_hafs',
          'ARRAY_AGG(DISTINCT word_translations.text) AS translations',
          'ARRAY_AGG(words.location ORDER BY words.word_index) AS locations',
          'COUNT(DISTINCT words.id) AS count'
        )
        .group('words.text_qpc_hafs')
        .order('count DESC')
  end

  def pending_suggestions
    Draft::Lemma.pending_contributions.where(lemma_id: lemma.id).includes(:user).order(:created_at)
  end

  def page_title
    case action_name
    when 'show'
      "Lemma #{lemma.text_madani}"
    when 'edit', 'update'
      "Suggest a fix: lemma #{lemma.text_madani}"
    else
      'Word lemmas'
    end
  end

  def meta_title
    page_title
  end

  def meta_description
    'Proofread and suggest fixes for the lemmas of Quran words and their meanings.'
  end
end
