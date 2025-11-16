# frozen_string_literal: true

ActiveJob::Base.queue_adapter = :sidekiq # default queue adapter

Rails.application.configure do
  config.active_job.queue_adapter = :sidekiq
  config.action_mailbox.queues.routing = 'mailers'
  config.active_storage.queues.analysis = 'active_storage_analysis'
  config.active_storage.queues.purge = 'low'
  config.active_storage.queues.mirror = 'low'
  config.action_mailer.deliver_later_queue_name = 'mailers'
end

require 'sidekiq/web'
require 'sidekiq-scheduler/web'
require 'sidekiq-status'
require 'sidekiq-status/web'

Sidekiq.logger.level = Logger::WARN
Sidekiq.default_job_options['backtrace'] = true

Sidekiq.configure_server do |config|
  Sidekiq::Status.configure_server_middleware config
  Sidekiq::Status.configure_client_middleware config

  # Load the schedule
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file('config/sidekiq_scheduler.yml')
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  Sidekiq::Status.configure_client_middleware config
end
