class TranslationResourcePresenter < ResourcePresenter
  def meta_title
    if action_name == 'detail'
      ayah = load_ayah(fallback_key: '73:4')
      "#{resource.name} translation for Surah #{ayah.chapter.name_simple} — Ayah #{ayah.verse_number}"
    else
      "Download Quran Translations"
    end
  end

  def meta_description
    if action_name == 'detail'
      translation_text.presence || "Translation of the Quran by #{resource.name}"
    else
      "Explore full Quran translations by various scholars with footnotes and context for every verse."
    end
  end

  def meta_keywords
    [
      resource.name,
      'Quran translation'
    ].join(', ')
  end

  private

  def translation_text
    translation = Translation.find_by(
      resource_content_id: resource.resource_content_id,
      verse_id: load_ayah(fallback_key: '73:4').id
    )

    if translation
      clean_meta_description translation.text
    end
  end
end
