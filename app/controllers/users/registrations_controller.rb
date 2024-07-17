# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]

  def after_inactive_sign_up_path_for(resource_name)
    new_user_session_path
  end
  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(
      :sign_up, keys: %i[
      password
      password_confirmation
      remember_me
      email
      first_name
      last_name
      email
      about_me])
  end
end
