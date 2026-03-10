class SurahInfosController < CommunityController
  before_action :authenticate_user!, only: [:new, :edit, :update, :create]
  before_action :authorize_access!, only: [:new, :edit, :update, :create]
  def index;end

  def show;end

  def edit;end

  def update
    @info = ChapterInfo.where(language: language, chapter_id: params[:id]).first

    if @info.update(info_params)
      redirect_to surah_info_path(@info.chapter_id, resource: @resource.id, language_id: @info.language_id), notice: "Info updated successfully."
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

  def language
    return @language if @language

    @available_languages = Language.where(id: ResourceContent.chapter_info.select(:language_id))
    # default will be English
    params[:language] = (params[:language].presence || params[:language_id].presence || 38).to_i
    @language = Language.find(params[:language])
  end

  def init_presenter
    @presenter = SurahInfosPresenter.new(self)
  end
end