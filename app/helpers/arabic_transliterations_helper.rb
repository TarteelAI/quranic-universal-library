module ArabicTransliterationsHelper
  def sort_order_link(text, sort_key, url_params = {}, link_options = {})
    order = params[:sort_order] && params[:sort_order] == 'asc' ? 'desc' : 'asc'

    icon_asc = "<i class='fa fa-sort-up #{'active' if order == 'desc' && params[:sort_key] == sort_key.to_s}'></i>"
    icon_desc = "<i class='fa fa-sort-down #{'active' if order == 'asc' && params[:sort_key] == sort_key.to_s}'></i>"

    url_params.merge!(
      sort_key: sort_key,
      sort_order: order,
      filter_chapter: params[:filter_chapter],
      filter_verse: params[:filter_verse],
      filter_progress: params[:filter_progress]
    )

    link_options[:class] = "d-flex sort-link #{link_options[:class]}"

    link_to url_for(url_params), link_options do
      "<span class='label-text tw-me-2'>#{text}</span> <span class='sort-icons'>#{icon_asc} #{icon_desc}</span>".html_safe
    end
  end
end
