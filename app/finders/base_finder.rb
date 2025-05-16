class BaseFinder
  attr_reader :params,
              :lookahead

  def initialize(params = {})
    @params = params
    @lookahead = Api::ParamLookahead.new(params)
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