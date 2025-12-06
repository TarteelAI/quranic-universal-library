# frozen_string_literal: true
unless Rails.env.development?
  redis_url = ENV['REDIS_URL'] || 'localhost:6379'
  ENV['REDIS_URL'] = redis_url
end

require 'sidekiq/web'
require 'sidekiq-scheduler/web'
require 'sidekiq-status'
require 'sidekiq-status/web'

Sidekiq.logger.level = Logger::INFO
Sidekiq.default_job_options = { 'backtrace' => true }

Sidekiq.configure_server do |config|
  Sidekiq::Status.configure_server_middleware config
  Sidekiq::Status.configure_client_middleware config
end

Sidekiq.configure_client do |config|
  Sidekiq::Status.configure_client_middleware config
end
