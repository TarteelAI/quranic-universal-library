class DownloadableResourceMailer < ApplicationMailer

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.downloadable_resource_mailer.new_update.subject
  #
  def new_update(resource, user, change_log = nil)
    @user = user
    @resource = resource
    @change_log = change_log
    @resource_type = resource.group_name.presence || resource.resource_type.to_s.tr('-', ' ').titleize
    @subject = "Updated #{@resource_type} Available: #{resource.name}"

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
