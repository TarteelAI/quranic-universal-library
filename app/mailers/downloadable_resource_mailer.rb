class DownloadableResourceMailer < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.downloadable_resource_mailer.new_update.subject
  #
  def new_update(resource, user)
    @user = user
    @resource = resource
    @subject = "New Update Available for Your Downloaded Resource(#{resource.name})"

    mail to: user.email, subject: @subject
  end

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.downloadable_resource_mailer.new_resource.subject
  #
  def new_resource(resource, user)
    @user = user
    @resource = resource
    @subject = "New Resource Added to QUL – Explore It Now!"

    mail to: user.email, subject: @subject
  end
end
