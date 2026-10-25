class TranslationPresenter < ResourcePresenter
  def ayah_translations
    ResourceContent.translations.one_verse
  end

  def translations
    @translations ||= paginate(filtered_translations)
  end

  def translation
    return @translation if defined?(@translation)

    @translation = Translation
                     .includes(:foot_notes, verse: :chapter)
                     .where(resource_content_id: resource.id)
                     .find_by(verse_id: params[:id])
  end

  def suggestion
    @suggestion ||= Draft::TranslationSuggestion.new(translation)
  end

  def page_title
    case action_name
    when 'index'
      "Ayah Translation Proofreading"
    when 'show'
      "#{resource_name} - #{ayah_label}"
    when 'edit', 'update'
      "Edit: #{ayah_label} - #{resource_name}"
    else
      "Ayah Translation Proofreading"
    end
  end

  def meta_title
    case action_name
    when 'index'
      "Translation Proofreading Tool"
    when 'show', 'edit'
      "#{resource_name} - #{ayah_label}"
    else
      "Translation Proofreading Tool"
    end
  end

  def meta_description
    case action_name
    when 'index'
      "Collaborate to improve Quran translations. Spot and fix typos, clarity issues, or OCR errors in translated ayahs across multiple languages."
    when 'show'
       default_description
    when 'edit'
      "Edit translation for #{ayah_label} in #{resource_name}. Submit suggestions for improvements."
    else
      default_description
    end
  end

  def meta_keywords
    case action_name
    when 'index'
      'Quran translation, proofreading, translation improvement, OCR correction, multilingual review'
    else
      "Quran translation, #{ayah_label}, #{resource_name}, proofreading, translation review"
    end
  end

  private

  def filtered_translations
    list = Translation.includes(:foot_notes, verse: :chapter).where(resource_content_id: resource.id)
    list = list.where("verses.chapter_id": params[:filter_chapter].to_i) if params[:filter_chapter].to_i > 0
    list = list.where("verses.verse_number": params[:verse_number].to_i) if params[:verse_number].to_i > 0
    list = list.text_search(params[:query]) if params[:query].present?

    list.order("verses.verse_index #{sort_order}")
  end

  def ayah_label
    translation&.verse&.human_label || "Ayah"
  end

  def resource_name
    @resource&.name || "Translation"
  end

  def default_description
    "Review translation for #{ayah_label} in #{resource_name}. Verify accuracy and suggest improvements."
  end
end
