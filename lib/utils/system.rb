module Utils
  class System
    def self.start_sidekiq
      if sidekiq_stopped?
        system "bundle exec sidekiq -e #{Rails.env.to_s} -d &"
      end
    rescue Exception => e
      Sentry.capture_exception(e)
    end

    def self.sidekiq_stopped?
      require 'sidekiq/api'

      ps = Sidekiq::ProcessSet.new
      ps.size.zero?
    rescue Exception => e
      Sentry.capture_exception(e)

      true
    end
  end
end