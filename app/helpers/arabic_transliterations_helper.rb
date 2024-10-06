module ArabicTransliterationsHelper
  def sort_order_link(text, sort_key, link_params = {})
    order = params[:sort_order] && params[:sort_order] == 'asc' ? 'desc' : 'asc'

    icon_asc = "<i class='fa fa-sort-up #{'active' if order == 'desc' && params[:sort_key] == sort_key.to_s}'></i>"
    icon_desc = "<i class='fa fa-sort-down #{'active' if order == 'asc' && params[:sort_key] == sort_key.to_s}'></i>"

    link_params.merge!(
      sort_key: sort_key,
      sort_order: order,
      filter_chapter: params[:filter_chapter],
      filter_verse: params[:filter_verse],
      filter_progress: params[:filter_progress]
    )

    link_to url_for(link_params), class: "d-flex sort-link" do
      "<span class='sort-icons me-1'>#{icon_asc} #{icon_desc}</span> <span class='label-text'>#{text}</span>".html_safe
    end
  end
end
