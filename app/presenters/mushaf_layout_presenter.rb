class MushafLayoutPresenter < ApplicationPresenter
  def page_title
    case action_name
    when 'index'
      "Mushaf Layouts"
    when 'show'
      "#{resource.name} - Page #{page_number}"
    when 'edit'
      "Update #{resource.name} - Page #{page_number}"
    end
  end

  def meta_title
    case action_name
    when 'index'
      "Mushaf Layouts"
    when 'show'
      "#{resource.name} Layout - Page #{page_number}"
    when 'edit'
      "Edit #{resource.name} Layout - Page #{page_number}"
    end
  end

  def meta_description
    # Adjust the meta description based on the action
    case action_name
    when 'index'
      "Customize Quran Mushaf page layouts. Adjust lines per page, align verses, map page ranges."
    else
      "Edit layout for #{resource.name} Mushaf page #{page_number}. Adjust word placement and line alignment."
    end
  end

  def meta_keywords
    case action_name
    when 'index'
      "Mushaf layout, Quran page layout, line alignment, page mapping"
    else
      "Mushaf layout, #{resource.name}, page #{page_number}, word placement, line alignment"
    end
  end
end