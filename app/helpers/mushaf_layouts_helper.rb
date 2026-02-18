module MushafLayoutsHelper
  def mushaf_sort_link(text, sort_key, url_params = {}, link_options = {})
    current_order = params[:sort_order] || 'asc'
    current_key = params[:sort_key]
    
    if current_key == sort_key.to_s
      order = current_order == 'asc' ? 'desc' : 'asc'
    else
      order = 'desc'
    end

    icon_asc = "<i class='fa fa-sort-up #{'active' if current_order == 'asc' && current_key == sort_key.to_s}'></i>"
    icon_desc = "<i class='fa fa-sort-down #{'active' if current_order == 'desc' && current_key == sort_key.to_s}'></i>"

    url_params.merge!(
      sort_key: sort_key,
      sort_order: order
    )

    link_options[:class] = "d-flex sort-link hover:tw-text-[#46ac7a] tw-transition-colors #{link_options[:class]}"

    link_to mushaf_layout_path(url_params), link_options do
      "<span class='label-text tw-me-2'>#{text}</span> <span class='sort-icons'>#{icon_asc} #{icon_desc}</span>".html_safe
    end
  end
end
