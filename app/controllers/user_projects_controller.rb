class UserProjectsController < ApplicationController
  before_action :authenticate_user_logged_in

  def new
     @user_project = UserProject.new(resource_content_id: params[:resource_id])
     render layout: false
  end

  def create
    @user_project = current_user.user_projects.build(user_project_params)

    if @user_project.save
      flash[:notice] = 'Request submitted successfully'
    else
      flash[:alert] = "Please fix the errors below"
      render_turbo_validations(@user_project)
    end
  end

  private

  def user_project_params
    params
      .require(:user_project)
      .permit(
        :resource_content_id,
        :reason_for_request,
        :language_proficiency,
        :motivation_and_goals,
        :review_process_acknowledgment,
        :additional_notes
      )
  end
end