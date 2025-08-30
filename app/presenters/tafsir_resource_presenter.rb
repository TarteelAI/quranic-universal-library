class TafsirResourcePresenter < ResourcePresenter
  def meta_title
    if action_name == 'detail'
      ayah = load_ayah(fallback_key: '73:4')
      "#{resource.name} tafsir for Surah #{ayah.chapter.name_simple} — Ayah #{ayah.verse_number}"
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
    tafsir = Tafsir.for_verse(load_ayah(fallback_key: '73:4'), resource.resource_content)

    clean_meta_description(tafsir.text) if tafsir
  end
end
