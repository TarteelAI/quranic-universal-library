class SurahInfosPresenter < ApplicationPresenter
  # A language can have several surah info resources (one per book).
  # The selected resource wins unless a different language was picked,
  # then the first resource of that language is shown.
  def resource_content
    return @resource_content if defined?(@resource_content)

    language_id = params[:language_id].presence&.to_i
    selected = surah_info_resources.find { |r| r.id == params[:resource_id].to_i } if params[:resource_id].present?
    selected = nil if selected && language_id && selected.language_id != language_id
    selected ||= surah_info_resources.find { |r| r.language_id == language_id } if language_id

    # By default show english surah info
    @resource_content = selected || surah_info_resources.find { |r| r.id == 58 }
  end

  def surah_info_resources
    @surah_info_resources ||= ResourceContent.chapter_info.includes(:language).order(:language_id, :id).to_a
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
