module ArabicTransliterationsHelper
  def sort_order_link(text, sort_key, link_params = {})
    order   = params[:sort_order] && params[:sort_order] == 'asc' ? 'desc' : 'asc'

    link_params.merge!(
        sort_key: sort_key,
        sort_order: order,
        filter_chapter: params[:filter_chapter],
        filter_verse: params[:filter_verse],
        filter_progress: params[:filter_progress]
    )

    link_to url_for(link_params) do
      "<i class='fa fa-sort-#{order} left'> </i> #{text}".html_safe
    end
  end
end
