class AyahThemesController < CommunityController
  before_action :authenticate_user!, only: %i[edit update]

  def index
  end

  def show
  end

  def edit
  end

  def update
    theme = @presenter.theme

    if suggestion_acknowledged? && theme.save_suggestions(theme_params, current_user)
      redirect_to theme_path(theme.id), notice: "Your suggestion is saved. The theme is updated once it's approved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def theme_params
    params.require(:ayah_theme).permit(:theme, :keywords, :verse_number_from, :verse_number_to, :comment)
  end

  def init_presenter
    @presenter = AyahThemesPresenter.new(self)
  end
end
