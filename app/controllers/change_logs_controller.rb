class ChangeLogsController < ApplicationController
  def index
  end

  def show
  end

  protected

  def init_presenter
    @presenter = ChangeLogsPresenter.new(self)
  end
end
