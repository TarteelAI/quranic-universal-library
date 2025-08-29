class TranslationResourcePresenter < ApplicationPresenter
  def meta_title
    if action_name == 'detail'
      "#{resource.name} translation for Surah #{load_surah.name_simple} — Ayah #{verse_number}"
    else
      "Quran Translations"
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
    Translation.find_by(
      resource_content_id: resource.resource_content_id,
      verse_id: load_ayah.id
    )&.text
  end
end
