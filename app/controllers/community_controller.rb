class CommunityController < ApplicationController
  DEFAULT_LANGUAGE = 174 # We're focusing on Urdu atm
  helper_method :current_language
  before_action :load_resource_access

  def tools
    @tools = view_context.developer_tools

    sort_by = params[:sort_key]
    sort_order = params[:sort_order].to_s == 'desc' ? 'desc' : 'asc'

    if sort_by.present? && ['name'].include?(sort_by)
      @tools = @tools.sort_by { |resource| resource[sort_by.to_sym] }
      @tools.reverse! if sort_order == 'desc'
    end
  end

  def ayah_boundaries
    render layout: false
  end

  def docs
    render layout: false if request.xhr?
  end

  def credits
    @contributors = Contributor.published
    @github_contributors = GithubService.fetch_contributors(limit: 20)
  end

  def faq
    @items = Faq.published
  end

  def tool_help
    render layout: false
  end

  def chars_info
    require "unicode/name"
    @presenter = CharInfoPresenter.new(self)
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

  def init_presenter
    @presenter = CommunityPresenter.new(self)
  end
end
