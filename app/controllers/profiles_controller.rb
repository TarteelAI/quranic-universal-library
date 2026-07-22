class ProfilesController < CommunityController
  before_action :authenticate_user!

  def show
  end

  def edit
  end

  def update
    updated = if password_or_email_change?
                current_user.update_with_password(account_update_params)
              else
                current_user.update(profile_update_params)
              end

    if updated
      bypass_sign_in(current_user)
      redirect_to profile_path, notice: update_notice
    else
      flash.now[:alert] = "Please fix the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def init_presenter
    @presenter = ProfilePresenter.new(self)
  end

  private

  def password_or_email_change?
    changing_password? || changing_email?
  end

  def changing_password?
    submitted_params[:password].present?
  end

  def changing_email?
    submitted_params[:email].present? && submitted_params[:email] != current_user.email
  end

  def submitted_params
    params.fetch(:user, {})
  end

  def account_update_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :current_password)
  end

  def profile_update_params
    params.require(:user).permit(:first_name, :last_name, :email)
  end

  def update_notice
    if current_user.pending_reconfirmation?
      "Account updated. Check #{current_user.unconfirmed_email} to confirm your new email address."
    else
      "Your account has been updated."
    end
  end
end
