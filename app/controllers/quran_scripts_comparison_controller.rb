class QuranScriptsComparisonController < CommunityController
  before_action :normalize_page_param, only: %i[compare_words]
  before_action :init_presenter

  def compare_words
  end

  protected

  def init_presenter
    @presenter = QuranScriptsComparisonPresenter.new(self)
  end
end


