class ChangeLogsController < ApplicationController
  before_action :normalize_page_param, only: %i[index]
  def index
  end

  def show
  end

  protected

  def init_presenter
    @presenter = ChangeLogsPresenter.new(self)
  end
end
