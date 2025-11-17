class ApplicationController < ActionController::Base
  before_action :init_presenter

  include Pagy::Backend
  helper_method :pagy
  include SeoHelper

  rescue_from ActionController::UnknownFormat,
              ActionController::RoutingError,
              ::AbstractController::ActionNotFound,
              ActiveRecord::RecordNotFound,
              with: ->(exception) { render_error 404, exception }

  protect_from_forgery with: :exception
  before_action :set_paper_trail_whodunnit
  def not_found
    render 'shared/not_found'
  end

  protected

  def init_presenter
    @presenter = ApplicationPresenter.new(self)
  end

  def authenticate_user_logged_in
    session[:use_modal] = params.key?(:modal)
    authenticate_user!
  end

  def user_for_paper_trail
    current_user&.to_gid
  end

  def sort_order
    s = (params[:sort_order].presence || 'asc').downcase

    if ['asc', 'desc'].include?(s)
      s
    else
      'asc'
    end
  end


  def can_manage?(resource)
    return false unless current_user

    if resource
      @access = if current_user.is_super_admin?
                  AdminProjectAccess.new
                else
                  access = current_user.user_projects.find_by(resource_content_id: resource.id)
                  access if access&.approved?
                end
    end
  end

  def access_denied_for_admin_resource(exception)
    redirect_to admin_root_path, alert: exception.message
  end

  def render_error(_status, exception)
    raise exception if Rails.env.development?

    render 'shared/not_found', formats: [:html], status: 404
  end

  def render_turbo_validations(resource, options = {})
    if options[:now_flash]
      flash.now[:alert] = 'Please fix the validation errors and try again.'
    else
      flash[:alert] = 'Please fix the validation errors and try again.'
    end

    action = options[:action] || action_name
    render "shared/turbo_resource_actions/#{action}",
           locals: { resource: resource },
           status: :unprocessable_entity
  end

end

class AdminProjectAccess
  def admin_notes
  end
end