# Server-side rendering for request specs. SSR is off in the test environment
# (config/initializers/inertia_rails.rb); `SsrServer.with_ssr { … }` starts the production SSR
# bundle and turns SSR on for the block, so a spec can read the server-rendered HTML.
#
# The bundle comes from `bin/vite build --ssr` (or `RAILS_ENV=test node_modules/.bin/vite build
# --ssr`), which writes public/vite-ssr. bin/gate builds it before RSpec.
require 'socket'

module SsrServer
  BUNDLE = Rails.root.join('public/vite-ssr/ssr.mjs')
  SOURCES = Rails.root.join('app/frontend')
  PORT = 13_714

  def self.with_ssr
    check_bundle!
    raise "Port #{PORT} is in use: stop the other SSR server (a node ssr.mjs) first." if listening?

    pid = Process.spawn('node', BUNDLE.to_s, out: File::NULL, err: File::NULL, pgroup: true)
    wait_for_port(pid)
    InertiaRails.configuration.merge!(InertiaRails::Configuration.new(ssr_enabled: true, ssr_raise_on_error: true))
    yield
  ensure
    InertiaRails.configuration.merge!(InertiaRails::Configuration.new(ssr_enabled: false, ssr_raise_on_error: false))
    stop(pid) if pid
  end

  def self.check_bundle!
    raise "No SSR bundle at #{BUNDLE}. Run `bin/vite build --ssr` first." unless BUNDLE.exist?

    newest_source = Dir[SOURCES.join('**/*.{ts,tsx,css}')].map { |file| File.mtime(file) }.max
    return if File.mtime(BUNDLE) >= newest_source

    raise "The SSR bundle is older than app/frontend. Run `bin/vite build --ssr` again."
  end

  def self.wait_for_port(pid)
    50.times do
      raise 'The SSR server exited before it listened.' if Process.wait(pid, Process::WNOHANG)
      return if listening?

      sleep 0.1
    end
    raise "The SSR server did not listen on port #{PORT}."
  end

  def self.listening?
    TCPSocket.new('localhost', PORT).close
    true
  rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
    false
  end

  def self.stop(pid)
    Process.kill('TERM', -pid)
    Process.wait(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end
end
