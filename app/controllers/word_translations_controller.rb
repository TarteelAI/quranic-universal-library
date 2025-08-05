class WordTranslationsController < CommunityController
  before_action :authorize_access!, only: [:new, :edit, :update, :create]
  before_action :init_presenter
  def index
    @word_translation_languages = Language.where(id: ResourceContent.translations.one_word.select('language_id'))

    verses = Verse
    if params[:filter_juz].to_i > 0
      verses = verses.where(juz_number: params[:filter_juz].to_i)
    end

    if params[:filter_chapter].to_i > 0
      verses = verses.where(chapter_id: params[:filter_chapter].to_i)
    end

    if params[:verse_number].to_i > 0
      verses = verses.where(verse_number: params[:verse_number].to_i)
    end

    if params[:filter_missing] == 'true'
      verses = verses.verses_with_missing_translations(language.id)
    end

    @pagy, @verses = pagy(verses.order("verse_index #{sort_order}"))
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
      return redirect_back fallback_location: word_translations_path(language: language.id), alert: 'Verse not found'
    end

    prepare_wbw_translations
  end

  def create
    @verse = Verse.find(params[:verse_id])
    @verse.update_word_translations(wbw_translations_params)

    redirect_to word_translation_path(@verse, language: language.id)
  end

  def group_info
    @word_translation = WordTranslation.where(
      word_id: params[:word_id],
      language_id: language.id
    ).first_or_initialize
    @verse = @word_translation.word&.verse

    if request.post?
      if @word_translation.create_or_update_group_translation(group_translation_params)
        flash[:notice] = 'Group info updated'
        prepare_wbw_translations
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
      :text,
      :group_text,
      :group_word_id
    ]
  end

  def eager_load_translations
    case language.id
    when 174 # Urdu
      [54, 97]
    when 185 # Chinese
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

  def load_resource
    @resource ||= ResourceContent.translations.one_word.where(language: language).first
  end

  def load_resource_access
    @access = can_manage?(load_resource)
  end

  def prepare_wbw_translations
    @wbw_translations = []

    @verse.words.order('position asc').each_with_index do |word, i|
      next if word.char_type_name == 'end'
      wbw_translation = @verse
                          .word_translations
                          .where(language_id: language.id)
                          .find_or_initialize_by(word_id: word.id)

      @wbw_translations << wbw_translation
    end
  end

  def init_presenter
    @presenter = WordTranslationsPresenter.new(self)
  end
end