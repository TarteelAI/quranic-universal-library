class MushafLayoutPresenter < BasePresenter
  attr_reader :mushaf, :action_name, :page_number

  def initialize(view_context, mushaf: nil, action_name:, page_number: nil)
    super(view_context)
    @mushaf = mushaf
    @action_name = action_name
    @page_number = page_number
  end

  def page_title
    case action_name
    when 'index'
      "Mushaf Layouts"
    when 'show'
      "#{mushaf.name} - Page #{page_number}"
    when 'edit'
      "#{mushaf.name} - Page #{page_number}"
    end
  end

  def meta_title
    case action_name
    when 'index'
      "Mushaf Layouts"
    when 'show'
      "#{mushaf.name} Layout - Page #{page_number}"
    when 'edit'
      "Edit #{mushaf.name} Layout - Page #{page_number}"
    end
  end

  def meta_description
    case action_name
    when 'index'
      "Customize Quran Mushaf page layouts. Adjust lines per page, align verses, map page ranges."
    else
      "Edit layout for #{mushaf.name} Mushaf page #{page_number}. Adjust word placement and line alignment."
    end
  end

  def meta_keywords
    case action_name
    when 'index'
      "Mushaf layout, Quran page layout, line alignment, page mapping"
    else
      "Mushaf layout, #{mushaf.name}, page #{page_number}, word placement, line alignment"
    end
  end
end