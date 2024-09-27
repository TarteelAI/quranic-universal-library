Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  config.background_worker_threads = 1
  config.environment = Rails.env

  config.enabled_environments = %w[production staging]

  config.excluded_exceptions += [
    ActionController::BadRequest,
    ActionController::UnknownFormat,
    ActionController::RoutingError,
    ActiveRecord::RecordNotFound
  ]

  config.rails.report_rescued_exceptions = false

  # dependency info
  config.send_modules = false

  # Send user ip, query string, cookies to sentry
  config.send_default_pii = true

  # The sampling factor to apply to events. A value of 0.0 will not send
  # any events, and a value of 1.0 will send 100% of events.
  config.sample_rate = 0.8

  # sample rate for tracing events (transactions)
  config.traces_sample_rate = 0.2

  # enable profiling
  # this is relative to traces_sample_rate
  config.profiles_sample_rate = 0.5

  # Report exception to sentry when retry is exhausted
  config.sidekiq.report_after_job_retries = true
end
