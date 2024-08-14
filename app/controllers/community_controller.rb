class CommunityController < ApplicationController
  helper_method :current_language
  before_action :load_resource_access

  def tools
  end

  def credits
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

  def load_resource_access
  end

  def authorize_access!
    if !load_resource_access
      if request.format.turbo_stream?
        render turbo_stream: turbo_stream.replace('flash-messages', partial: 'shared/permission_denied')
      elsif request.format.json?
        render json: { error: 'Permission Denied' }
      else
        return redirect_to(root_path, notice: "Sorry you don't have permission to access this page.")
      end
    end
  end
end
