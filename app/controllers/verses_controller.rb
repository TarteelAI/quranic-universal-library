class VersesController < CommunityController
  before_action :set_presenter

  def compare
  end

  protected

  def set_presenter
    @presenter = VersesPresenter.new(self)
  end
end
