class TafsirPresenter < ResourcePresenter
  def page_title
    case action_name
    when 'index'
      "Ayah tafsir proofreading"
    when 'show'
      "#{resource_name} - #{verse_key}"
    when 'edit'
      "Edit: #{verse_key} - #{resource_name}"
    else
      "Ayah tafsir proofreading"
    end
  end

  def meta_title
    case action_name
    when 'index'
      "Tafsir proofreading Tool"
    when 'show', 'edit'
      "#{resource_name} - #{verse_key}"
    else
      "Tafsir proofreading Tool"
    end
  end

  def meta_description
    case action_name
    when 'index'
      "Collaborate to improve Quran Tafsir. Spot and fix typos, clarity issues, or OCR errors in translated ayahs across multiple languages."
    when 'show'
      default_description
    when 'edit'
      "Edit Tafsir for Ayah #{verse_key} in #{resource_name}. Submit suggestions for improvements."
    else
      default_description
    end
  end

  def meta_keywords
    case action_name
    when 'index'
      'Quran Tafsir, proofreading'
    else
      "Quran Tafsir, #{verse_key}, #{resource_name}, proofreading, Tafsir review"
    end
  end

  private

  def verse_key
    @translation&.verse&.verse_key || "Ayah"
  end

  def resource_name
    @resource&.name || "Tafsir"
  end

  def default_description
    "Review translation for Ayah #{verse_key} in #{resource_name}. Verify accuracy and suggest improvements."
  end
end
