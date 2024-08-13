module ApplicationHelper
  include Pagy::Frontend

  def has_filters?(*filters)
     filters.detect do |f|
       params[f].present?
     end
  end

  def font_ids(verses)
    pages = {}
    verses.each do |v|
      pages[v.page_number] = true
      pages[v.v2_page] = true
    end

    pages.keys
  end
end
