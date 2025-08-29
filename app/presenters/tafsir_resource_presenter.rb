class TafsirResourcePresenter < ResourcesPresenter
  def meta_title
    if action_name == 'detail'
      "#{resource.name} tafsir for Surah #{load_surah.name_simple} — Ayah #{verse_number}"
    else
      super
    end
  end

  def meta_description
    if action_name == 'detail'
      tafsir_text.presence || meta_title
    else
      super
    end
  end

  def meta_keywords
    [
      resource.name,
      'Quran tafsir'
    ].join(', ')
  end

  private

  def tafsir_text
    text = Tafsir.for_verse(load_ayah, resource.resource_content)&.text

    text.truncate(160, separator: ' ') if text
  end
end
