class Users::SessionsController < Devise::SessionsController
  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  rescue HTML5::ParseError, ActionController::InvalidAuthenticityToken, ActionController::ParameterMissing, Devise::Strategies::DatabaseAuthenticatable::Error
    # This is a bit simplified, but Devise usually throws :warden on failure
    # and redirects to failure app. For Turbo we want to stay on the same page and show errors.
    render_error_response
  end

  protected

  def render_error_response
    render 'new', status: :unprocessable_entity
  end

  def store_return_url
    session["user_return_to"] = params[:user_return_to] || session["user_return_to"]
  end
end