class TafsirResourcePresenter < ResourcePresenter
  def meta_title
    if action_name == 'detail'
      "Download #{resource.name}"
    else
      super
    end
  end

  def meta_description
    if action_name == 'detail'
      meta_title
    else
      super
    end
  end

  def meta_keywords
    [
      resource.name,
      'Tafsir data',
      'Download Tafsir'
    ].join(', ')
  end
end
