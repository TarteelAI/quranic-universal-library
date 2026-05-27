class TafsirResourcePresenter < ResourcePresenter
  def meta_title
    if action_name == 'detail'
      "Download #{resource.name} — Tafsir JSON Data"
    else
      super
    end
  end

  def meta_description
    if action_name == 'detail'
      "Download #{resource.name} — Quran tafsir JSON data for every ayah."
    else
      super
    end
  end

  def meta_keywords
    [
      resource.name,
      "#{resource.name} json data",
      'Tafsir data',
      'Quran tafsir json data',
      'Download Tafsir',
      'Quran data'
    ].join(', ')
  end
end
