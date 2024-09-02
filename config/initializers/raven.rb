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
  # it's not activated by default, but you can enable it with
  config.send_modules = true # if you don't want to send all the dependency info

  config.sample_rate = 0

  # set a uniform sample rate between 0.0 and 1.0
  config.traces_sample_rate = 0.10
end
