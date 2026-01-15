class Users::SessionsController < Devise::SessionsController
  def create
    self.resource = resource_class.find_for_database_authentication(email: sign_in_params[:email])

    if resource&.valid_password?(sign_in_params[:password])
      if resource.active_for_authentication?
        resource.remember_me = sign_in_params[:remember_me] if resource.respond_to?(:remember_me=)
        set_flash_message!(:notice, :signed_in)
        sign_in(resource_name, resource)
        yield resource if block_given?
        respond_with resource, location: after_sign_in_path_for(resource)
      else
        set_flash_message!(:notice, :"signed_in_but_#{resource.inactive_message}")
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_in_path_for(resource)
      end
    else
      self.resource = resource_class.new(sign_in_params)
      clean_up_passwords(resource)
      flash.now[:alert] = I18n.t("devise.failure.invalid", authentication_keys: resource_class.authentication_keys.join(", "))
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  protected

  def render_error_response
    render 'new', status: :unprocessable_entity
  end

  def store_return_url
    session["user_return_to"] = params[:user_return_to] || session["user_return_to"]
  end
end