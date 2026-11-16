class ShowcaseProjectsController < CommunityController
  before_action :authenticate_user!, except: :index
  before_action :load_own_project, only: %i[edit update]

  def index
    @projects = ShowcaseProject.published.with_attached_logo
    @own_projects = ShowcaseProject.where(user: current_user).order(created_at: :desc) if user_signed_in?
  end

  def new
    @project = ShowcaseProject.new
  end

  def create
    @project = ShowcaseProject.new(project_params.merge(user: current_user))

    if @project.save
      redirect_to showcase_projects_path, notice: "Thanks! We'll review your project and publish it soon."
    else
      flash.now[:alert] = 'Please fix the errors below.'
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params.merge(published: false))
      redirect_to showcase_projects_path, notice: "Your changes were saved. We'll review them and publish the project again soon."
    else
      flash.now[:alert] = 'Please fix the errors below.'
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def init_presenter
    @presenter = ShowcaseProjectPresenter.new(self)
  end

  private

  def load_own_project
    @project = ShowcaseProject.where(user: current_user).find(params[:id])
  end

  def project_params
    params.require(:showcase_project).permit(
      :name,
      :project_type,
      :description,
      :qul_resources_used,
      :website_url,
      :app_store_url,
      :play_store_url,
      :repository_url,
      :owner_name,
      :owner_type,
      :logo_file,
      platforms: []
    )
  end
end
