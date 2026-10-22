class TransliterationProofreadingsController < CommunityController
  before_action :normalize_page_param, only: %i[index]
  before_action :load_resource_access
  before_action :authenticate_user!, only: %i[edit update]
  before_action :authorize_access!, only: %i[edit update]
  before_action :ensure_verse, only: %i[show edit update]

  def index
  end

  def show
  end

  def edit
  end

  def update
    transliteration = @presenter.transliteration
    transliteration.save_suggestions(transliteration_params, current_user)

    redirect_to transliteration_proofreading_path(transliteration.verse_id, resource_id: @resource.id),
                notice: 'Your suggestions are saved successfully'
  end

  protected

  # A missing transliteration is fine, the suggestion creates it once approved.
  def ensure_verse
    if @presenter.verse.blank?
      redirect_to transliteration_proofreadings_path(resource_id: @resource.id),
                  alert: 'Sorry ayah not found.'
    end
  end

  def transliteration_params
    params.require(:draft_transliteration).permit(:draft_text)
  end

  # @resource is shared with tools/header and the access request partials
  def load_resource_access
    @resource = @presenter.resource
    @access = can_manage?(@resource)
  end

  def init_presenter
    @presenter = TransliterationPresenter.new(self)
  end
end
