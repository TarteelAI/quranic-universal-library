class SurahInfosController < CommunityController
  before_action :authenticate_user!, only: [:new, :edit, :update, :create]
  before_action :authorize_access!, only: [:new, :edit, :update, :create]
  def index;end

  def show;end

  def edit;end

  def update
    info = @presenter.resource

    if info.save_suggestions(info_params, current_user)
      redirect_to surah_info_path(info.id), notice: 'Your suggestions are saved, they go live once approved.'
    else
      @presenter.draft.assign_attributes(info_params)
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def info_params
    params.require(:draft_surah_info).permit(:draft_short_text, :draft_text)
  end

  def load_resource_access
    @access = can_manage?(@presenter.resource_content)
  end

  def init_presenter
    @presenter = SurahInfosPresenter.new(self)
  end
end