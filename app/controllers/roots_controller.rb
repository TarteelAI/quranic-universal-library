class RootsController < CommunityController
  before_action :authenticate_user!, only: %i[edit update]

  def index
  end

  def show
  end

  def edit
  end

  def update
    root = @presenter.root

    if suggestion_acknowledged? && root.save_suggestions(root_params, current_user)
      redirect_to arabic_root_path(root.id), notice: "Your suggestion is saved. The root is updated once it's approved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def root_params
    params.require(:root).permit(:arabic_trilateral, :english_trilateral, :text_uthmani, :en_meanings, :ur_meanings, :comment)
  end

  def init_presenter
    @presenter = RootsPresenter.new(self)
  end
end
