# frozen_string_literal: true

require "fileutils"
require "time"
require "json"
require "securerandom"
require "digest"
require "active_support/security_utils"

# Site wide maintenance switch.
#
# Toggled by the presence of a flag file so it survives app restarts and can be
# flipped from a shell.
#
#   bundle exec rails runner 'MaintenanceMode.on!(minutes: 60)'
#   bundle exec rails runner 'MaintenanceMode.off!'
#
# or without Ruby at all:
#
#   mkdir -p /tmp/maintenance && echo '{}' > /tmp/maintenance/qul
#   rm /tmp/maintenance/qul
#
# While it is on, MaintenanceMode::Middleware answers every request with
# public/maintenance.html (503), except the health check and the handful of
# static assets that page needs. Anyone holding the bypass token keeps full
# access to the site.
class MaintenanceMode
  DEFAULT_FLAG_PATH = "#{Rails.root}/tmp/maintenance/qul"

  BYPASS_PARAM  = "qul_access"
  BYPASS_COOKIE = "qul_maintenance_access"
  BYPASS_HEADER = "HTTP_X_QUL_MAINTENANCE"
  BYPASS_TTL    = 12 * 60 * 60 # seconds

  # Paths that keep working while the site is down. /health is what the
  # maintenance page polls to notice we are back.
  OPEN_PREFIXES = [
    "/health",
    "/fonts/",
    "/favicon",
    "/maintenance.html",
    "/apple-touch-icon",
    "/site.webmanifest"
  ].freeze

  class << self
    def flag_path
      ENV["MAINTENANCE_FLAG_PATH"].presence || DEFAULT_FLAG_PATH
    end

    def on?
      File.exist?(flag_path)
    end
    alias_method :enabled?, :on?

    def off?
      !on?
    end

    # MaintenanceMode.on!(minutes: 90, message: "Upgrading to Postgres 18")
    #
    # eta: anything Time-ish (Time, ActiveSupport::TimeWithZone, ISO8601 string)
    # minutes: shorthand for "eta is N minutes from now"
    def on!(minutes: nil, eta: nil, message: nil, token: nil)
      eta ||= Time.now.utc + (minutes * 60) if minutes

      payload = {
        "started_at" => Time.now.utc.iso8601,
        "eta" => normalize_time(eta),
        "message" => message.presence,
        "token" => token.presence || bypass_token
      }.compact

      FileUtils.mkdir_p(File.dirname(flag_path))
      File.write(flag_path, JSON.pretty_generate(payload))
      reset_cache!

      log_banner(payload)
      true
    end
    alias_method :enable!, :on!

    def off!
      FileUtils.rm_f(flag_path)
      reset_cache!
      Rails.logger&.info("[MaintenanceMode] OFF — site is live again") if defined?(Rails)
      false
    end
    alias_method :disable!, :off!

    # Contents of the flag file, re-read only when the file changes.
    def status
      path = flag_path
      return {} unless File.exist?(path)

      stamp = [path, File.mtime(path).to_i, File.size(path)]
      return @status if defined?(@status) && @status_stamp == stamp

      @status_stamp = stamp
      @status = parse(File.read(path))
    rescue SystemCallError
      {}
    end

    def message
      status["message"].presence ||
        "We're upgrading QUL's infrastructure. Everything will be back shortly, insh'Allah."
    end

    def eta
      status["eta"].presence
    end

    def started_at
      status["started_at"].presence
    end

    # Seconds to advertise in Retry-After. Falls back to 10 minutes.
    def retry_after
      return 600 unless eta

      remaining = (Time.parse(eta) - Time.now.utc).to_i
      remaining.clamp(60, 24 * 60 * 60)
    rescue ArgumentError, TypeError
      600
    end

    def bypass_token
      from_flag = status["token"].presence
      return from_flag if from_flag

      ENV["MAINTENANCE_BYPASS_TOKEN"].presence || derived_token
    end

    def bypass?(token)
      token.present? && ActiveSupport::SecurityUtils.secure_compare(token.to_s, bypass_token.to_s)
    rescue StandardError
      false
    end

    def bypass_url(host = "https://qul.tarteel.ai")
      "#{host}/?#{BYPASS_PARAM}=#{bypass_token}"
    end

    def reset_cache!
      remove_instance_variable(:@status) if defined?(@status)
      remove_instance_variable(:@status_stamp) if defined?(@status_stamp)
    end

    private

    def derived_token
      base = Rails.application.secret_key_base.to_s
      Digest::SHA256.hexdigest("qul-maintenance-bypass:#{base}")[0, 24]
    end

    def normalize_time(value)
      return nil if value.blank?
      return value.utc.iso8601 if value.respond_to?(:utc)

      Time.parse(value.to_s).utc.iso8601
    rescue ArgumentError, TypeError
      nil
    end

    def parse(raw)
      parsed = JSON.parse(raw.to_s)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end

    def log_banner(payload)
      return unless defined?(Rails) && Rails.logger

      Rails.logger.info("[MaintenanceMode] ON — #{payload.to_json}")
      Rails.logger.info("[MaintenanceMode] bypass: #{bypass_url}")
      puts "Maintenance mode is ON." if $stdout.tty?
      puts "Bypass link: #{bypass_url}" if $stdout.tty?
    end
  end
end

require_relative "maintenance_mode/middleware"
