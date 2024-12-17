class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAILER_SENDER', 'no-reply@tarteel.ai')
  layout 'mailer'
end
