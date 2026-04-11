class ChangeLogMailer < ApplicationMailer
  def announcement(change_log, user)
    @user = user
    @change_log = change_log
    @resource_content = change_log.resource_content
    @downloadable_resource = change_log.public_downloadable_resource

    mail to: user.email, subject: "QUL changelog update: #{change_log.title}"
  end
end
