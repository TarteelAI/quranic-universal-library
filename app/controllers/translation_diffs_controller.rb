class TranslationDiffsController < AdminsController
  def index
  end

  def show

  end

  protected
  def init_presenter
    @presenter = TranslationDiffPresenter.new(self)
  end
end