class MushafLayoutResourcesPresenter < ResourcePresenter
  def initialize(params, resource = nil)
    super(params)
    @resource = resource
  end

  def meta_title
    if action_name == 'detail'
      "#{@resource.name} preview of page #{page_number}"
    else
      "Mushaf Layout Resources"
    end
  end

  def meta_description
    if action_name == 'detail'
      "Preview of page #{page_number} of the #{resource.name}. Download #{resource.name} data for your application."
    else
      super
    end
  end

  def meta_keywords
    "#{resource.name}, Mushaf layout, Quran Mushaf layout, Quran page images, Quran page data, Quran page preview, download #{resource.name}, page #{page_number}"
  end
end
