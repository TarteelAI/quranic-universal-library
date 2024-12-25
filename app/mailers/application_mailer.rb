class ApplicationMailer < ActionMailer::Base
  include Rails.application.routes.url_helpers

  default from: ENV.fetch('MAILER_SENDER', 'no-reply@tarteel.ai')
  layout 'mailer'
end
