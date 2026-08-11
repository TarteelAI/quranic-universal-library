require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Qul
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    config.eager_load_paths << "#{config.root}/lib"

    qul_scripts_lib = File.join(config.root, "qul-scripts")

    eager_load_paths = [
      File.join(qul_scripts_lib, "lib"),
      *%w[models controllers jobs].map { |dir| File.join(qul_scripts_lib, "app", dir) }
    ]

    eager_load_paths.each do |path|
      config.eager_load_paths << path if File.directory?(path)
    end

    [
      [config.paths["app/views"], File.join(qul_scripts_lib, "app/views")],
      [config.paths["db/migrate"], File.join(qul_scripts_lib, "db/migrate")]
    ].each do |paths, path|
      paths << path if File.directory?(path)
    end

    config.assets.css_compressor = :escompress
    config.active_support.to_time_preserves_timezone = :zone

    config.active_record.yaml_column_permitted_classes = [
      Symbol,
      Date,
      Time,
      ActiveSupport::TimeWithZone,
      ActiveSupport::TimeZone,
      ActiveSupport::HashWithIndifferentAccess,
      BigDecimal
    ]

    ActionView::Base.field_error_proc = Proc.new do |html_tag, instance|
      html_tag.html_safe
    end
  end
end
