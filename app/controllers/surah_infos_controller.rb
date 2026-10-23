class SurahInfosController < CommunityController
  before_action :authenticate_user!, only: [:new, :edit, :update, :create]
  before_action :authorize_access!, only: [:new, :edit, :update, :create]
  def index;end

  def show;end

  def edit;end

  def update
    @info = ChapterInfo.find(params[:id])

    if @info.update(info_params)
      redirect_to surah_info_path(@info.id), notice: "Info updated successfully."
    else
      render action: :edit
    end
  end

  protected

  def info_params
    params.require(:chapter_info).permit(:short_text, :text)
  end

  def load_resource_access
    @access = can_manage?(@presenter.resource_content)
  end

  def init_presenter
    @presenter = SurahInfosPresenter.new(self)
  end
end