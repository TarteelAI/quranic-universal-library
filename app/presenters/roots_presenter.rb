class RootsPresenter < ApplicationPresenter
  MISSING = {
    'root_word' => 'No root word',
    'en_meanings' => 'No English meaning',
    'ur_meanings' => 'No Urdu meaning'
  }.freeze

  def roots
    list = Root.all

    case params[:missing]
    when 'root_word'
      list = list.where(text_uthmani: [nil, ''])
    when 'en_meanings'
      list = list.where(en_translations: nil)
    when 'ur_meanings'
      list = list.where(ur_translations: nil)
    end

    if params[:query].present?
      text = params[:query].strip
      query = "%#{ActiveRecord::Base.sanitize_sql_like(text)}%"
      # Arabic letters can be typed with or without spaces
      letters = text.gsub(/\s+/, '').chars.join(' ')
      list = list.where(
        'arabic_trilateral = :letters OR english_trilateral = :text OR text_uthmani ILIKE :query OR en_translations::text ILIKE :query OR ur_translations::text ILIKE :query',
        letters: letters, text: text, query: query
      )
    end

    paginate(list.order(words_count: :desc, id: :asc))
  end

  def root
    @root ||= Root.find(params[:id])
  end

  # Each form of the root in the Quran, most used first
  def word_forms
    Word.unscoped
        .left_joins(:word_translation)
        .where(root_id: root.id)
        .where('word_translations.language_id = 38 OR word_translations.id IS NULL')
        .select(
          'words.text_qpc_hafs',
          # The most common English translation of the form
          'MODE() WITHIN GROUP (ORDER BY word_translations.text) AS translation',
          'COUNT(DISTINCT words.id) AS count'
        )
        .group('words.text_qpc_hafs')
        .order('count DESC')
  end

  def pending_suggestions
    Draft::Root.pending_contributions.where(root_id: root.id).includes(:user).order(:created_at)
  end

  def page_title
    case action_name
    when 'show'
      "Root #{root.arabic_trilateral}"
    when 'edit', 'update'
      "Suggest a fix: root #{root.arabic_trilateral}"
    else
      'Word roots'
    end
  end

  def meta_title
    page_title
  end

  def meta_description
    'Proofread and suggest fixes for the roots of Quran words and their meanings.'
  end

end
