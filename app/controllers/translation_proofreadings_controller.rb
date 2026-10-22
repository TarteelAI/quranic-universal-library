class TranslationProofreadingsController < CommunityController
  before_action :normalize_page_param, only: %i[index]
  before_action :load_resource_access
  before_action :authenticate_user!, only: %i[edit update]
  before_action :authorize_access!, only: %i[edit update]
  before_action :ensure_translation, only: %i[show edit update]

  def show
  end

  def edit
  end

  def update
    if @presenter.suggestion.assign(suggestion_params).save(current_user)
      redirect_to translation_proofreading_path(@presenter.translation.verse_id, resource_id: @resource.id),
                  notice: "Your suggestion is saved. The translation is updated once it's approved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def index
  end

  protected

  def ensure_translation
    if @presenter.translation.blank?
      redirect_to translation_proofreadings_path(resource_id: @resource.id), alert: "Sorry translation not found for this ayah."
    end
  end

  def suggestion_params
    params.require(:suggestion).permit(:text, :comment, footnotes: %i[foot_note_id text])
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
