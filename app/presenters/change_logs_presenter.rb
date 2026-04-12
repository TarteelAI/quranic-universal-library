class ChangeLogsPresenter < ApplicationPresenter
  def change_logs
    paginate scoped
  end

  def change_log
    scoped.find(params[:id])
  end

  def page_title
    if index?
      'QUL change logs'
    else
      change_log.title
    end
  end

  def page_description
    if index?
      'Updates and changes to the Quranic Universal Library'
    else
      change_log.experpt
    end
  end

  def scoped
    ChangeLog
      .published
      .latest
      .includes(:user, :resource_content)
  end
end