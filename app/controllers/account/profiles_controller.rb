# frozen_string_literal: true

module Account
  # The signed-in user's own pages (`account` page group): the profile (/profile), the account
  # settings (/profile/edit) and the update both settings forms send (PATCH /profile). The update
  # follows the rules of the old ProfilesController: a new email or password needs the current
  # password, a name or "about me" change does not.
  class ProfilesController < InertiaController
    before_action :require_sign_in

    META = { robots: 'noindex' }.freeze

    def show
      profile = Profile.new(user: current_user, params:, tool_for: helpers.method(:resource_tool),
                            cms_path_for: helpers.method(:contribution_cms_url),)
      raise ActiveRecord::RecordNotFound unless profile.page_in_range?

      render_inertia 'account/ProfilePage', locals: profile.to_h,
                                            meta: page_meta(title: 'Your profile - QUL', **META)
    end

    def edit
      render_inertia 'account/SettingsPage', locals: Profile.settings(current_user),
                                             meta: page_meta(title: 'Account settings - QUL', **META)
    end

    def update
      updated = if password_or_email_change?
                  current_user.update_with_password(account_params)
                else
                  current_user.update(account_params.except(:password, :password_confirmation, :current_password))
                end

      if updated
        bypass_sign_in(current_user)
        redirect_to account_profile_path, notice: update_notice
      else
        redirect_to account_settings_path, inertia: { errors: current_user.errors.to_hash(true) }
      end
    end

    private

    # Sign-in is an old page, so an Inertia request leaves the app with a full visit.
    def require_sign_in
      return if user_signed_in?

      return_to = request.get? ? request.fullpath : account_settings_path
      sign_in_path = new_user_session_path(user_return_to: return_to)
      request.inertia? ? inertia_location(sign_in_path) : redirect_to(sign_in_path)
    end

    def password_or_email_change?
      submitted = params.fetch(:user, {})
      submitted[:password].present? || (submitted[:email].present? && submitted[:email] != current_user.email)
    end

    def account_params
      params.expect(user: [:first_name, :last_name, :email, :about_me, :password, :password_confirmation,
                           :current_password,])
    end

    def update_notice
      if current_user.pending_reconfirmation?
        "Account updated. Check #{current_user.unconfirmed_email} to confirm your new email address."
      else
        'Your account has been updated.'
      end
    end
  end
end
