class MushafLayoutResourcesPresenter < BasePresenter
  attr_reader :resource

  GENERIC_DESCRIPTION = "Download high-resolution Mushaf layouts optimized for printing and digital display, ensuring precise verse alignment and vibrant color fidelity."

  def initialize(params, resource = nil)
    super(params)
    @resource = resource
  end

  def meta_title
    if @resource.present?
      @resource.name
    else
      "Mushaf Layout Resources"
    end
  end

  def meta_description
    GENERIC_DESCRIPTION
  end

  def meta_keywords
    ["quran", "mushaf layout", "quran printing", "verse alignment", "high-res mushaf", "indopak mushaf", "13-line mushaf"].join(', ')
  end
end
