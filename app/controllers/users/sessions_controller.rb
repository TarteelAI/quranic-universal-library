class Users::SessionsController < Devise::SessionsController
  before_action :store_return_url, only: [:new]

  protected

  # store_location_for keeps only the path, so an off-site URL can't be used as a redirect target
  def store_return_url
    store_location_for(:user, params[:user_return_to]) if params[:user_return_to].present?
  end
end
