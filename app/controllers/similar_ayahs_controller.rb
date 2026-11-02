class SimilarAyahsController < CommunityController
  before_action :authenticate_user!, only: %i[edit update]

  def index
  end

  def show
  end

  def edit
  end

  def update
    verse = @presenter.verse

    if suggestion_acknowledged? && verse.save_similar_ayah_suggestions(similar_ayah_params, current_user)
      redirect_to similar_ayah_path(verse.id), notice: "Your suggestion is saved. The similar ayahs are updated once it's approved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def similar_ayah_params
    params.require(:similar_ayah).permit(:add_verse_keys, :both_ways_for_keys, :comment,
                                         keep_verse_ids: [], add_verse_ids: [], both_ways_verse_ids: [])
  end

  def init_presenter
    @presenter = SimilarAyahsPresenter.new(self)
  end
end
