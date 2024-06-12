# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  def create
    build_resource(permitted_params)

    if resource.save
      sign_in resource, store: true
      redirect_to after_sign_up_path_for(resource), notice: "Signup successfully!"
    else
      flash[:error] = "Please fix following errors and try again."
      render action: :new
    end
  end

  protected

  def after_sign_up_path_for(resource_or_scope)
    root_path
  end

  def permitted_params
    params.require(:user).permit(%i[
                                        password
                                        password_confirmation
                                        remember_me
                                        email
                                        first_name
                                        last_name
                                        email
                                        about_me
                                      ])
  end
end
