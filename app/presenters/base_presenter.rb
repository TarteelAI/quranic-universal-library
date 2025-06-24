class BasePresenter
  MAX_RECORDS_PER_PAGE = 50

  include Pagy::Backend
  attr_reader :params,
              :pagination,
              :lookahead

  def initialize(params)
    @params = params
    @lookahead = Api::ParamLookahead.new(params)
  end

  protected

  def current_page
    params[:page].to_i.abs.positive? ? params[:page].to_i : 1
  end

  def per_page
    10
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