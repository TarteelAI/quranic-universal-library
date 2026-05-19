# frozen_string_literal: true
env = Rails.env
host = env.development? ? 'localhost:3000' : 'qul.tarteel.ai'

Rails.application.configure do
  hosts = ['qul.tarteel.ai', 'localhost']
  config.hosts += hosts
  config.action_cable.allowed_request_origins = hosts

  if env.production? || env.staging?
    config.action_mailer.default_url_options = {
      host: host,
      protocol: 'https'
    }
  end
end

Rails.application.routes.default_url_options = {
  host: host,
  protocol: 'https'
}

