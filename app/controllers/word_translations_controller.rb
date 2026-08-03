class WordTranslationsController < CommunityController
  before_action :authorize_access!, only: [:new, :edit, :update, :create]
  before_action :require_resource, except: [:select_resource]

  def select_resource
  end

  def index
  end

  def show
    @verse = Verse
               .includes(:translations, :words)
               .where(translations: { resource_content_id: eager_load_translations })
               .find(params[:id])
  end

  def new
    verses = Verse
               .includes(:chapter, :translations)
               .where(translations: { resource_content_id: eager_load_translations })

    @verse = if params[:ayah].include?(':')
               verses.find_by(verse_key: params[:ayah])
             else
               verses.find_by(id: params[:ayah])
             end

    if @verse.blank?
      return redirect_back fallback_location: word_translations_path(resource_id: resource.id), alert: 'Verse not found'
    end
  end

  def create
    @verse = Verse.find(params[:verse_id])
    @verse.update_word_translations(wbw_translations_params)

    redirect_to word_translation_path(@verse, resource_id: resource.id)
  end

  def group_info
    @word_translation = @presenter.group_word_translation(params[:word_id])
    @verse = @word_translation.word&.verse

    if request.post?
      if @word_translation.create_or_update_group_translation(group_translation_params)
        flash[:notice] = 'Group info updated'
        render 'update_group_info'
      else
        render_turbo_validations(@word_translation, {action: :update})
      end
    end
  end

  protected

  def group_translation_params
    params
      .require(:word_translation)
      .permit(
        :word_range_from,
        :word_range_to,
        :group_word_id,
        :group_text
      )
  end

  def wbw_translations_params
    params.require(:verse).permit word_translations_attributes: [
      :id,
      :word_id,
      :language_id,
      :resource_content_id,
      :text,
      :group_text,
      :group_word_id
    ]
  end

  def eager_load_translations
    case language.id
    when 174 # Urdu
      [54, 97]
    when 185, 195, 196, 197 # Chinese(Traditional, Zhuyin, Pinyin, Simplified)
      [109, 56]
    when 175 # Uzbek
      [55, 127, 101]
    when 38 # English
      [131, 203]
    when 20 # Bengali
      [380, 213]
    else
      resources = ResourceContent.translations.one_verse.where(language_id: language.id).order('priority desc').pluck(:id)
      resources.first(2)
    end
  end

  def resource
    @resource ||= @presenter.resource
  end

  def require_resource
    if resource.blank?
      redirect_to select_resource_word_translations_path and return
    end
  end

  def language
    @language ||= resource&.language || super
  end

  alias current_language language

  def load_resource_access
    @access = can_manage?(resource)
  end

  def init_presenter
    @presenter = WordTranslationsPresenter.new(self)
  end
end
