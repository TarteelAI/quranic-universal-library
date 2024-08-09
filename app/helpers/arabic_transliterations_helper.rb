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

    link_to url_for(link_params), class: "d-flex align-items-center gap-2" do
      "<span><i class='fa fa-sort-#{order}'></i></span><span>#{text}</span>".html_safe
    end
  end
end
