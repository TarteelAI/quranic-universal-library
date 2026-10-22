class TransliterationPresenter < ResourcePresenter
  def resource
    @resource ||= if params[:resource_id].present?
                    ayah_transliterations.find(params[:resource_id])
                  else
                    ayah_transliterations.first!
                  end
  end

  def ayah_transliterations
    ResourceContent.transliteration.one_verse.order(:priority, :id)
  end

  # Ayahs with their transliteration text (nil when missing) as transliteration_text.
  def verses
    @verses ||= paginate(filtered_verses)
  end

  def verse
    return @verse if defined?(@verse)

    @verse = Verse.find_by(id: params[:id])
  end

  # Unsaved record when the ayah has no transliteration yet.
  def transliteration
    @transliteration ||= Transliteration.find_by(resource_content_id: resource.id, verse_id: verse.id) ||
                         Transliteration.new(
                           resource_content_id: resource.id,
                           verse: verse,
                           language_id: resource.language_id,
                           language_name: resource.language_name
                         )
  end

  def missing_transliteration?
    transliteration.new_record? || transliteration.text.blank?
  end

  def draft
    @draft ||= transliteration.build_draft
  end

  def pending_suggestions_count
    transliteration.drafts.where(imported: false, need_review: true).count
  end

  def page_title
    case action_name
    when 'show'
      "#{resource_name} - #{ayah_label}"
    when 'edit', 'update'
      "Edit: #{ayah_label} - #{resource_name}"
    else
      "Ayah Transliteration Proofreading"
    end
  end

  def meta_title
    case action_name
    when 'show', 'edit'
      "#{resource_name} - #{ayah_label}"
    else
      "Transliteration Proofreading Tool"
    end
  end

  def meta_description
    case action_name
    when 'index'
      "Collaborate to improve Quran transliterations. Spot and fix spelling, tajweed markup or syllable issues in ayah transliterations."
    when 'edit'
      "Edit transliteration for #{ayah_label} in #{resource_name}. Submit suggestions for improvements."
    else
      "Review transliteration for #{ayah_label} in #{resource_name}. Verify accuracy and suggest improvements."
    end
  end

  def meta_keywords
    case action_name
    when 'index'
      'Quran transliteration, proofreading, transliteration improvement, Quran in latin script'
    else
      "Quran transliteration, #{ayah_label}, #{resource_name}, proofreading, transliteration review"
    end
  end

  private

  def filtered_verses
    join = Verse.sanitize_sql_array([
      'LEFT JOIN transliterations ON transliterations.verse_id = verses.id AND transliterations.resource_content_id = ?',
      resource.id
    ])
    list = Verse.joins(join).includes(:chapter).select('verses.*, transliterations.text AS transliteration_text')

    list = list.where(chapter_id: params[:filter_chapter].to_i) if params[:filter_chapter].to_i > 0
    list = list.where(verse_number: params[:verse_number].to_i) if params[:verse_number].to_i > 0

    if params[:filter_missing] == 'true'
      list = list.where("transliterations.id IS NULL OR transliterations.text IS NULL OR transliterations.text = ''")
    end

    if params[:query].present?
      list = list.where('transliterations.text ILIKE ?', "%#{Transliteration.sanitize_sql_like(params[:query])}%")
    end

    list.order(verse_index: sort_order)
  end

  def ayah_label
    verse&.human_label || 'Ayah'
  end

  def resource_name
    resource&.name || 'Transliteration'
  end
end
