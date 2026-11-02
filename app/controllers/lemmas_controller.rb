class LemmasController < CommunityController
  before_action :authenticate_user!, only: %i[edit update]

  def index
  end

  def show
  end

  def edit
  end

  def update
    lemma = @presenter.lemma

    if suggestion_acknowledged? && lemma.save_suggestions(lemma_params, current_user)
      redirect_to lemma_path(lemma.id), notice: "Your suggestion is saved. The lemma is updated once it's approved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def lemma_params
    params.require(:lemma).permit(:text_madani, :text_clean, :en_meanings, :comment)
  end

  def init_presenter
    @presenter = LemmasPresenter.new(self)
  end
end
