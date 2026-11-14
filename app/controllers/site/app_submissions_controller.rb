# frozen_string_literal: true

module Site
  # POST /apps: the app submission form on the apps directory (`apps` page group). Only a
  # signed-in user can submit; the form shows a signed-out visitor a sign-in link that returns
  # to the open form (/apps?submit=1). A submission is an unpublished App row and enqueues nothing.
  class AppSubmissionsController < InertiaController
    before_action :require_sign_in

    def create
      app = App.new(submission_params.except(:icon).merge(user: current_user))
      app.icon_upload = submission_params[:icon] if submission_params[:icon].present?

      if app.save(context: :submission)
        redirect_to apps_directory_path
      else
        redirect_back_or_to apps_directory_path, inertia: { errors: app.errors.to_hash(true) }
      end
    end

    private

    # Sign-in is an old page, so an Inertia request leaves the app with a full visit.
    def require_sign_in
      return if user_signed_in?

      sign_in_path = new_user_session_path(user_return_to: apps_directory_path(submit: 1))
      request.inertia? ? inertia_location(sign_in_path) : redirect_to(sign_in_path)
    end

    def submission_params
      params.expect(app: [:name, :url, :contact, :consent, :icon, { platforms: [], uses: [] }])
    end
  end
end
