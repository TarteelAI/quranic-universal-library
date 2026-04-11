class ChangeLogsController < ApplicationController
  def index
    @pagy, @change_logs = pagy(change_logs_scope, items: per_page)
  end

  def show
    @change_log = change_logs_scope.find(params[:id])
  end

  protected

  def change_logs_scope
    ChangeLog
      .published
      .latest
      .includes(:user, :resource_content)
  end

  def per_page
    value = params[:per_page].to_i
    return 20 unless value.positive?

    [value, 100].min
  end
end
