class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch('MAILER_SENDER', 'cms@tarteel.ai')
  layout 'mailer'
end
