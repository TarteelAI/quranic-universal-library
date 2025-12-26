class AyahController < ApplicationController
  def show
    if request.xhr? || request.format.turbo_stream?
      render layout: false
    end
  end

  def text
    render partial: 'ayah/ayah_text', layout: false
  end

  def translations
    render partial: 'ayah/translations', layout: false
  end

  def tafsirs
    render partial: 'ayah/tafsirs', layout: false
  end

  def words
    render partial: 'ayah/words', layout: false
  end

  protected

  def init_presenter
    @presenter = AyahPresenter.new(self)
    @ayah = @presenter.ayah
    head :not_found unless @presenter.found?
  end
end