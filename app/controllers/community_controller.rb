class CommunityController < ApplicationController
  before_action :authenticate_user!
  helper_method :current_language

  def tools
  end

  def chars_info
    require "unicode/name"
  end

  def svg_optimizer
  end
  
  protected
  def language
    @language ||= load_language
  end

  alias current_language language

  def load_language
    lang_from_params = (params[:language].presence || params[:language_id] || DEFAULT_LANGUAGE).to_i
    lang = Language.find_by_id(lang_from_params) || Language.find(DEFAULT_LANGUAGE)
    params[:language] = lang.id

    lang
  end
end
