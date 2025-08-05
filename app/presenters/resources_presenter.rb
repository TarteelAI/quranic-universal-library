class ResourcesPresenter < BasePresenter
  include ResourceMeta

  def initialize(params, resource = nil)
    super(params)
    @resource = resource
  end

  def meta_title
    if @resource
      @resource.name
    elsif @params[:id].present?
      ResourceMeta.title_for(@params[:id])
    else
      'Quranic Resources'
    end
  end

  def meta_description
    if @resource
      return @resource.description if @resource.respond_to?(:description) && @resource.description.present?
      desc = ResourceMeta.description_for(resource_type_key)
      return desc if desc
      super
    elsif @params[:id].present?
      ResourceMeta.description_for(@params[:id]) || super
    else
      super
    end
  end

  def meta_keywords
    base_keywords = super
    seo_defaults = 'quran resources, tafsir resources, translations, quran translations, quran recitations'
    keywords = [base_keywords, seo_defaults]

    if @resource
      tags = @resource.downloadable_resource_tags.pluck(:name)
      keywords << tags.join(', ')
    elsif @params[:id].present?
      keywords << ResourceMeta.title_for(@params[:id])
    end

    keywords.join(', ').split(', ').map(&:strip).uniq.join(', ')
  end

  protected

  def resource_type_key
    return @resource.resource_type.to_s if @resource.respond_to?(:resource_type)
    return @resource.category.to_s if @resource.respond_to?(:category)
  end
end
