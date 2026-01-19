class Users::SessionsController < Devise::SessionsController
  before_action :store_return_url, only: [:new]

  protected

  def store_return_url
    session["user_return_to"] = params[:user_return_to] || session["user_return_to"]
  end
end