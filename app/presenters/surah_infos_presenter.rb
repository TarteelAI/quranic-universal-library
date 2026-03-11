class SurahInfosPresenter < ApplicationPresenter
  def resource_content
    # By default show english surah info
    filters = {}
    if params[:language_id].present?
      filters[:language_id] = params[:language_id].to_i
    else
      filters[:id] = params[:resource_id] || 58
    end

    ResourceContent
      .chapter_info
      .includes(:language)
      .where(filters).first
  end

  def language
    resource_content.language
  end

  def resource
    ChapterInfo.find(params[:id])
  end

  def resources
    list = ChapterInfo
             .where(resource_content_id: resource_content.id)
             .includes(:chapter)
             .order("chapter_id #{sort_order}")

    if params[:filter_chapter].present?
      list = list.where(chapter_id: params[:filter_chapter].to_i)
    end

    list
  end

  def available_languages
    Language.where(id: ResourceContent.chapter_info.select(:language_id).distinct)
  end

  def meta_title
    if show?
      source_name = resource.resource_content&.name
      base = "#{resource.chapter.name_simple}"
      source_name ? "#{base} – #{source_name} | Quranic Universal Library" : "#{base} – Surah Information | Quranic Universal Library"
    else
      'Surah Information – Names, Revelation Context & Sources | Quranic Universal Library'
    end
  end

  def meta_description
    if show?
      source_name = resource.resource_content&.name
      "Surah #{resource.chapter.name_simple} information#{source_name ? " from #{source_name}" : ''}: when and why it was revealed, name meaning and context. Part of Quranic Universal Library."
    else
      'Browse surah information from multiple sources: names, when and why each surah was revealed. Each source has its own resource content. Quranic Universal Library.'
    end
  end

  def meta_keywords
    'surah information, surah names, revelation context, when revealed, why revealed, Quran chapters, multiple sources, Quranic Universal Library'
  end
end
