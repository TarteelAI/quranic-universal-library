class AdminsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_access!
  before_action :init_presenter

  protected
  def authorize_access!
    if !current_user.super_admin?
      redirect_to root_path, alert: "You are not authorized to access this page"
    end
  end

  def init_presenter
  end
end