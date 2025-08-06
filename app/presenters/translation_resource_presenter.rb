class TranslationResourcePresenter < BasePresenter
  attr_reader :resource

  def initialize(params, resource = nil)
    super(params)
    @resource = resource
    @verse    = find_verse
  end

  def meta_title
    if verse_page?
      "#{resource.name} translation for Surah #{surah_name} — Ayah #{verse_number}"
    elsif resource_overview?
      "#{resource.name} translation"
    else
      "Quran Translations"
    end
  end

  def meta_description
    if verse_page?
      translation_text.presence || "Translation of the Quran by #{resource.name}"
    elsif resource_overview?
      if resource.respond_to?(:description) && resource.description.present?
        resource.description
      else
        "Explore the full Quran translation by #{resource.name}, with footnotes and contextual notes for every verse."
      end
    else
      "Explore full Quran translations by various scholars with footnotes and context for every verse."
    end
  end

  def meta_keywords
    if verse_page?
      base = "quran translation, #{resource.name.downcase} translation, islamic resources"
      "#{base}, surah #{surah_name}, ayah #{verse_number}"
    elsif resource_overview?
      tags = resource.downloadable_resource_tags.pluck(:name).map(&:downcase)
      (["quran translation", resource.name.downcase] + tags).uniq.join(', ')
    else
      "quran, islamic tools, muslim developers, quran api, quranic library"
    end
  end

  private

  def verse_page?
    @resource.present? && @params[:ayah].present?
  end

  def resource_overview?
    @resource.present? && @params[:ayah].blank?
  end

  def ayah_key
    @params[:ayah]
  end

  def find_verse
    Verse.find_by(verse_key: ayah_key) if ayah_key
  end

  def surah_name
    @verse&.chapter&.name_simple.to_s
  end

  def verse_number
    ayah_key.to_s.split(':').last.to_s
  end

  def translation_text
    return unless @verse && resource.resource_content_id

    Translation.find_by(
      resource_content_id: resource.resource_content_id,
      verse_id: @verse.id
    )&.text
  end
end
