class ApplicationController < ActionController::Base
  include Pagy::Backend

  protect_from_forgery with: :exception
  before_action :set_paper_trail_whodunnit

  protected
  def user_for_paper_trail
    current_user&.to_gid
  end

  def can_manage?(resource)
    return false unless current_user

    if resource
      @access = if current_user.admin?
                  AdminProjectAccess.new
                else
                  current_user.user_projects.find_by(resource_content_id: resource.id)
                end
    end
  end

  def access_denied_for_admin_resource(exception)
    redirect_to admin_root_path, alert: exception.message
  end
end

class AdminProjectAccess
  def admin_notes
    "Be careful Mr Admin!!"
  end
end