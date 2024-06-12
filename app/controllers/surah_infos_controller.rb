class SurahInfosController < CommunityController
  before_action :load_access
  before_action :check_permission, only: [:new, :edit, :update, :create, :history, :changes]

  def index
    @surah_infos = ChapterInfo.order("chapter_id ASC").where(language: language)

    if params[:filter_chapter].present?
      @surah_infos = @surah_infos.where(chapter_id: params[:filter_chapter].to_i)
    end
  end

  def show
    @info = ChapterInfo.where(language: language, chapter_id: params[:id]).first
  end

  def history
    @info = ChapterInfo.where(language: language, chapter_id: params[:id]).first
    render layout: false
  end

  def changes
    @info = ChapterInfo.where(language: language, chapter_id: params[:id]).first

    version = @info.versions.find(params[:version])
    @version_object = version.reify #@info.paper_trail.version_at params[:version]

    @next = @version_object.paper_trail.next_version
  end

  def edit
    @info = ChapterInfo.where(language: language, chapter_id: params[:id]).first
  end

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

  def wbw_translations_params
    params.require(:verse).permit wbw_translations_attributes: [
      :word_id,
      :language_id,
      :text_madani,
      :text_indopak,
      :text,
      :user_id,
      :id
    ]
  end

  def check_permission
    if @resource.blank? || @access.blank?
      redirect_to surah_infos_path(language_id: @language.id), alert: "Sorry you don't have access to this resource"
    end
  end

  def load_access
    @resource = ResourceContent.chapter_info.where(language: language).first
    @access = can_manage?(@resource)
  end

  def language
    if @language
      @language
    else
      @available_languages = Language.where(id: ResourceContent.chapter_info.select(:language_id))
      # default will be English
      params[:language] = (params[:language].presence || params[:language_id].presence || resource_content&.language_id || 38).to_i
      @language = Language.find(params[:language])
    end
  end

  def resource_content
    if params[:resource_id]
      ResourceContent.find_by(id: params[:resource_id])
    end
  end
end