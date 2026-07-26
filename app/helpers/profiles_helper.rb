module ProfilesHelper
  def profile_tab_link(name, tab, active_tab)
    active = tab == active_tab
    classes = active ? "bg-[#46ac7a] text-white" : "text-gray-600 hover:text-black"
    link_to name, profile_path(tab: tab),
            class: "px-4 py-2 text-sm rounded-md #{classes}",
            data: { turbo_frame: "profile_panel", turbo_action: "advance", remote_tab_target: "tab", action: "remote-tab#select" }
  end

  def contribution_filter_link(label, item_type, active_type)
    active = item_type == active_type
    classes = active ? "bg-[#46ac7a] text-white border-[#46ac7a]" : "text-gray-600 border-gray-200 hover:text-black"
    link_to label, profile_path(tab: "contributions", item_type: item_type),
            class: "text-xs px-3 py-1 rounded-full border #{classes}",
            data: { turbo_frame: "profile_panel" }
  end

  def contribution_cms_url(item)
    return nil unless item

    polymorphic_path([:cms, item])
  rescue StandardError
    nil
  end

  def resource_tool_url(resource_content)
    return nil unless resource_content

    case resource_content.sub_type
    when ResourceContent::SubType::Translation
      if resource_content.cardinality_type == ResourceContent::CardinalityType::OneWord
        word_translations_path(resource_id: resource_content.id)
      else
        translation_proofreadings_path(resource_id: resource_content.id)
      end
    when ResourceContent::SubType::Tafsir
      tafsir_proofreadings_path(resource_id: resource_content.id)
    when ResourceContent::SubType::Transliteration
      arabic_transliterations_path(resource_id: resource_content.id)
    end
  rescue StandardError
    nil
  end
end
