class TranslationProofreadingsController < CommunityController
  before_action :find_resource
  before_action :authenticate_user!, only: %i[edit update]
  before_action :authorize_access!, only: %i[edit update]

  def show
    #TODO: use presenter to load the translation
    @translation = Translation
                     .includes(:verse, :foot_notes)
                     .where(resource_content_id: @resource.id)
                     .find_by_verse_id(params[:id])

    if @translation.blank?
      return redirect_to translation_proofreading_path(resource_id: @resource.id), alert: "Sorry translation not found for this ayah."
    end
  end

  def edit
    @translation = Translation
                     .includes(:verse, :foot_notes)
                     .where(resource_content_id: @resource.id)
                     .find_by_verse_id(params[:id])

    if @translation.blank?
      return redirect_to translation_proofreading_path(resource_id: @resource.id), alert: "Translation not found"
    end
    @draft_translation = @translation.build_draft
  end

  def update
    @translation = Translation
                     .where(resource_content_id: @resource.id)
                     .find_by_verse_id(params[:id])

    if @translation.save_suggestions(translation_params, current_user)
      redirect_to translation_proofreading_path(@translation.verse.id, resource_id: @resource.id),
                  notice: 'Your suggestions are saved successfully'
    else
      render action: :edit, alert: @translation.errors.full_messages
    end
  end

  def index
    @ayah_translations = ResourceContent.translations.one_verse
    translations = Translation.includes(:verse, :foot_notes).where(resource_content_id: @resource.id)

    if params[:filter_chapter].to_i > 0
      translations = translations.where("verses.chapter_id": params[:filter_chapter].to_i)
    end

    if params[:verse_number].to_i > 0
      translations = translations.where("verses.verse_number": params[:verse_number].to_i)
    end

    if params[:query].present?
      translations = translations.text_search(params[:query])
    end

    order = if params[:sort_order] && params[:sort_order] == 'desc'
              'desc'
            else
              'asc'
            end

    @pagy, @translations = pagy(translations.order("verses.verse_index #{order}"))
  end

  protected

  def translation_params
    params.require(:draft_translation).permit(
      :draft_text,
      foot_notes_attributes: %i[
        id
        _destroy
        draft_text
        foot_note_id
      ]
    )
  end

  def find_resource
    return @resource if @resource

    params[:resource_id] ||= 131
    @resource = ResourceContent.find(params[:resource_id])
    @presenter.set_resource(@resource)
  end

  def load_resource_access
    @access = can_manage?(find_resource)
  end

  def init_presenter
    @presenter = TranslationPresenter.new(self)
  end
end
