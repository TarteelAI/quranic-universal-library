class WordRootsController < CommunityController
  before_action :authenticate_user!, only: %i[edit update]

  def index
  end

  def show
  end

  def edit
  end

  def update
    verse = @presenter.verse
    @errors = suggestion_acknowledged? ? Word.save_root_suggestions(verse, word_params, current_user, comment: params[:comment]) : []

    if suggestion_acknowledged? && @errors.empty?
      redirect_to word_root_path(verse.id), notice: "Your suggestion is saved. The words are updated once it's approved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  # { word_id => { root:, stem:, lemma: } }
  def word_params
    params.require(:words).permit(@presenter.words.map { |word| { word.id.to_s => %i[root stem lemma] } }).to_h
  end

  def init_presenter
    @presenter = WordRootsPresenter.new(self)
  end
end
