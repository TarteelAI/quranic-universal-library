class WordTransliterationProofreadingsController < CommunityController
  before_action :normalize_page_param, only: %i[index]
  before_action :load_resource_access
  before_action :authenticate_user!, only: %i[edit update]
  before_action :ensure_verse, only: %i[show edit update]

  def index
  end

  def show
  end

  def edit
  end

  def update
    verse = @presenter.verse
    WordTransliteration.save_suggestions(verse, @resource, word_transliteration_params, current_user, comment: params[:comment])

    redirect_to word_transliteration_proofreading_path(verse.id, resource_id: @resource.id),
                notice: 'Your suggestions are saved successfully'
  end

  protected

  def ensure_verse
    if @presenter.verse.blank?
      redirect_to word_transliteration_proofreadings_path(resource_id: @resource.id),
                  alert: 'Sorry ayah not found.'
    end
  end

  # { word_id => text }
  def word_transliteration_params
    params.require(:word_transliterations).permit(@presenter.words.map { |w| w.id.to_s }).to_h
  end

  # @resource is shared with tools/header and the access request partials
  def load_resource_access
    @resource = @presenter.resource
    @access = can_manage?(@resource)
  end

  def init_presenter
    @presenter = WordTransliterationPresenter.new(self)
  end
end
