class TranslationPresenter < ResourcePresenter
  def page_title
    case action_name
    when 'index'
      "Ayah Translation Proofreading"
    when 'show'
      "#{resource_name} - #{verse_key}"
    when 'edit'
      "Edit: #{verse_key} - #{resource_name}"
    else
      "Ayah Translation Proofreading"
    end
  end

  def meta_title
    case action_name
    when 'index'
      "Translation Proofreading Tool"
    when 'show', 'edit'
      "#{resource_name} - #{verse_key}"
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
      "Edit translation for Ayah #{verse_key} in #{resource_name}. Submit suggestions for improvements."
    else
      default_description
    end
  end

  def meta_keywords
    case action_name
    when 'index'
      'Quran translation, proofreading, translation improvement, OCR correction, multilingual review'
    else
      "Quran translation, #{verse_key}, #{resource_name}, proofreading, translation review"
    end
  end

  private

  def verse_key
    @translation&.verse&.verse_key || "Ayah"
  end

  def resource_name
    @resource&.name || "Translation"
  end

  def default_description
    "Review translation for Ayah #{verse_key} in #{resource_name}. Verify accuracy and suggest improvements."
  end
end
