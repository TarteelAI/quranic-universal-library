class StemsPresenter < ApplicationPresenter
  def stems
    list = Stem.all

    if params[:query].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query].strip)}%"
      list = list.where('text_clean ILIKE :query OR text_madani ILIKE :query', query: query)
    end

    paginate(list.order(words_count: :desc, id: :asc))
  end

  def stem
    @stem ||= Stem.find(params[:id])
  end

  # Each word with this stem, most used first
  def word_forms
    Word.unscoped
        .left_joins(:word_translation)
        .where(stem_id: stem.id)
        .where('word_translations.language_id = 38 OR word_translations.id IS NULL')
        .select(
          'words.text_qpc_hafs',
          'ARRAY_AGG(DISTINCT word_translations.text) AS translations',
          'COUNT(DISTINCT words.id) AS count'
        )
        .group('words.text_qpc_hafs')
        .order('count DESC')
  end

  def pending_suggestions
    Draft::Stem.pending_contributions.where(stem_id: stem.id).includes(:user).order(:created_at)
  end

  def page_title
    case action_name
    when 'show'
      "Stem #{stem.text_madani}"
    when 'edit', 'update'
      "Suggest a fix: stem #{stem.text_madani}"
    else
      'Word stems'
    end
  end

  def meta_title
    page_title
  end

  def meta_description
    'Proofread and suggest fixes for the stems of Quran words.'
  end
end
