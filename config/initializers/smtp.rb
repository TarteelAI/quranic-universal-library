env = Rails.env
Rails.application.configure do
  config.action_mailer.perform_deliveries = !env.test?

  if env.staging? || env.production?
    ActionMailer::Base.smtp_settings = {
      address: ENV['SMTP_ADDRESS'],
      port: ENV['SMTP_PORT'],
      # authentication: ENV['SMTP_AUTHENTICATION'].to_sym,
      user_name: ENV['SMTP_USERNAME'],
      password: ENV['SMTP_PASSWORD'],
      enable_starttls_auto: true
    }
  else
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.delivery_method = :letter_opener
  end
end
