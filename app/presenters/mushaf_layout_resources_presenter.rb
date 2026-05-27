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
      "Preview page #{page_number} of #{resource.name} and download the Mushaf layout as JSON data — line, page and word position data for your application."
    else
      super
    end
  end

  def meta_keywords
    "#{resource.name}, #{resource.name} json data, Mushaf layout, Quran Mushaf layout, Quran page images, Quran page data, Quran layout json data, Quran data, Quran page preview, download #{resource.name}, page #{page_number}"
  end
end
