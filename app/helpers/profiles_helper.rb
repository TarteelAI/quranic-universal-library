module ProfilesHelper
  def profile_tab_link(name, tab, active_tab)
    active = tab == active_tab
    classes = active ? "bg-[#46ac7a] text-white" : "text-gray-600 hover:text-black"
    link_to name, profile_path(tab: tab),
            class: "px-4 py-2 text-sm rounded-md #{classes}",
            data: { turbo_frame: "profile_panel", turbo_action: "advance", remote_tab_target: "tab", action: "remote-tab#select" }
  end

  def contribution_filter_link(label, item_type, active_type)
    profile_filter_chip label, profile_path(tab: "contributions", item_type: item_type), item_type == active_type
  end

  def download_filter_link(label, resource_type, active_type)
    profile_filter_chip label, profile_path(tab: "downloads", download_type: resource_type), resource_type == active_type
  end

  def resource_filter_link(label, sub_type, active_type)
    profile_filter_chip label, profile_path(tab: "resources", resource_type: sub_type), sub_type == active_type
  end

  def profile_filter_chip(label, url, active)
    classes = active ? "bg-[#46ac7a] text-white border-[#46ac7a]" : "text-gray-600 border-gray-200 hover:text-black"
    link_to label, url,
            class: "text-xs px-3 py-1 rounded-full border #{classes}",
            data: { turbo_frame: "profile_panel" }
  end

  def contribution_cms_url(item)
    return nil unless item

    polymorphic_path([:cms, item])
  rescue StandardError
    nil
  end

  def resource_tool(resource_content)
    return { label: nil, url: nil } unless resource_content

    case resource_content.sub_type
    when ResourceContent::SubType::Translation
      if resource_content.cardinality_type == ResourceContent::CardinalityType::OneWord
        { label: "Word translation", url: word_translations_path(resource_id: resource_content.id) }
      else
        { label: "Ayah translation", url: translation_proofreadings_path(resource_id: resource_content.id) }
      end
    when ResourceContent::SubType::Tafsir
      { label: "Tafsir", url: tafsir_proofreadings_path(resource_id: resource_content.id) }
    when ResourceContent::SubType::Transliteration
      { label: "Transliteration", url: arabic_transliterations_path(resource_id: resource_content.id) }
    when ResourceContent::SubType::Audio
      audio_resource_tool(resource_content)
    when ResourceContent::SubType::Layout
      mushaf = Mushaf.find_by(resource_content_id: resource_content.id)
      { label: "Mushaf layout", url: mushaf ? mushaf_layout_path(mushaf.id) : nil }
    when ResourceContent::SubType::Info
      { label: "Surah info", url: surah_infos_path(language_id: resource_content.language_id) }
    when ResourceContent::SubType::Mutashabihat
      { label: "Mutashabihat", url: morphology_phrases_path }
    else
      { label: resource_content.sub_type&.humanize, url: nil }
    end
  rescue StandardError
    { label: resource_content&.sub_type&.humanize, url: nil }
  end

  private

  def audio_resource_tool(resource_content)
    ayah_recitation = Recitation.find_by(resource_content_id: resource_content.id)
    if ayah_recitation
      return { label: "Ayah audio", url: ayah_audio_files_path(id: ayah_recitation.id) }
    end

    surah_recitation = Audio::Recitation.find_by(resource_content_id: resource_content.id)
    if surah_recitation
      return { label: "Surah audio", url: surah_audio_files_path(recitation_id: surah_recitation.id) }
    end

    { label: "Audio", url: nil }
  end
end
