class ApplicationPresenter
  MAX_RECORDS_PER_PAGE = 50

  include Pagy::Backend
  attr_reader :params,
              :pagination,
              :lookahead,
              :context,
              :resource

  def initialize(context)
    @context = context
    @params = context.params
    @lookahead = Api::ParamLookahead.new(params)
  end

  def action_name
    context.action_name
  end

  def index?
    action_name == 'index'
  end

  def show?
    action_name == 'show'
  end

  def set_resource(resource)
    @resource = resource
  end

  def page_number
    params[:page] || '1'
  end

  def meta_tags
    {
      title: meta_title,
      description: meta_description,
      keywords: meta_keywords,
      image: og_image
    }
  end

  def meta_title
    'Quranic Universal Library'
  end

  def meta_description
    'A comprehensive collection of Quranic digital resources'
  end

  def meta_keywords
    'quran, islamic tools, muslim developers, quran api, quranic library'
  end

  def og_image
    'https://static-cdn.tarteel.ai/qul/og.jpeg'
  end

  protected
  def paginate(list)
    @pagination, list = pagy(list)
    list
  end

  def current_page
    params[:page].to_i.abs.positive? ? params[:page].to_i : 1
  end

  def mushaf_id
    params[:mushaf] || 5
  end

  def invalid_chapter(value)
    raise_invalid_id_error(value, "Chapter", "1-114")
  end

  def invalid_juz(value)
    raise_invalid_id_error(value, "Juz", "1-30")
  end

  def invalid_manzil(value)
    raise_invalid_id_error(value, "Manzil", "1-7")
  end

  def invalid_hizb(value)
    raise_invalid_id_error(value, "Hizb", "1-60")
  end

  def invalid_rub_el_hizb(value)
    raise_invalid_id_error(value, "Rub el Hizb", "1-240")
  end

  def invalid_mushaf_page(value, max_page = 604)
    raise_invalid_id_error(value, "Mushaf Page", "1-#{max_page}")
  end

  def invalid_ruku(value)
    raise_invalid_id_error(value, "Ruku", "1-558")
  end

  def raise_invalid_id_error(invalid_value, resource_type, range)
    raise ::Api::RecordNotFound.new("#{invalid_value} #{resource_type} ID or slug is invalid. Please select a valid slug or #{resource_type} ID from #{range}.")
  end

  def per_page
    items = params[:per_page].to_i.abs
    [items | 10, MAX_RECORDS_PER_PAGE].min
  end

  def api_locale
    locale = params[:locale].presence || 'en'

    if available_locales.include?(locale)
      locale
    else
      'en'
    end
  end

  def available_locales
    @locales ||= Language.where(id: TranslatedName.pluck(:language_id).uniq).pluck(:iso_code)
  end
end