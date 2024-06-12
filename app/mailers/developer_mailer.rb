class DeveloperMailer < ApplicationMailer
  def notify(to:, subject:, message:, file_path: nil)
    @message = message

    if file_path
      attachments[File.basename(file_path)] = open(file_path).read
    end

    mail from: ENV.fetch('MAILER_SENDER', 'cms@tarteel.ai'), to: to, subject: subject
  end
end