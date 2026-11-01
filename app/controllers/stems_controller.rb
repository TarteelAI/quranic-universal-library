class StemsController < CommunityController
  before_action :authenticate_user!, only: %i[edit update]

  def index
  end

  def show
  end

  def edit
  end

  def update
    stem = @presenter.stem

    if suggestion_acknowledged? && stem.save_suggestions(stem_params, current_user)
      redirect_to stem_path(stem.id), notice: "Your suggestion is saved. The stem is updated once it's approved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def stem_params
    params.require(:stem).permit(:text_madani, :text_clean, :comment)
  end

  def init_presenter
    @presenter = StemsPresenter.new(self)
  end
end
