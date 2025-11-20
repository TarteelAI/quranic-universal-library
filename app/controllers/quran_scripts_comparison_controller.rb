class QuranScriptsComparisonController < CommunityController
  before_action :init_presenter

  def compare_words
  end

  protected

  def init_presenter
    @presenter = QuranScriptsComparisonPresenter.new(self)
  end
end


