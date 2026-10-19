# frozen_string_literal: true

require "rack/utils"

class MaintenanceMode
  # Serves public/maintenance.html for every request while the flag file is
  # present. Sits at the very bottom of the middleware stack so it also covers
  # ActiveAdmin, Sidekiq's web UI and the API.
  class Middleware
    HTML_PATH = "public/maintenance.html"

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless MaintenanceMode.on?

      request = Rack::Request.new(env)
      return @app.call(env) if open_path?(request.path)

      param = query_token(request)
      return clear_bypass if param == "off"

      # ?qul_access=<token> hands out a cookie and redirects to the clean URL,
      # so the secret stays out of the address bar, Referer headers and logs.
      return grant_bypass(request) if MaintenanceMode.bypass?(param) && safe_method?(request)

      return @app.call(env) if MaintenanceMode.bypass?(param)
      return @app.call(env) if MaintenanceMode.bypass?(stored_token(request))

      json_request?(request) ? json_response : html_response
    end

    private

    def open_path?(path)
      MaintenanceMode::OPEN_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    end

    def safe_method?(request)
      request.get? || request.head?
    end

    # A malformed query string should never take the whole site down, hence the
    # rescues around every bit of request parsing.
    def query_token(request)
      request.params[MaintenanceMode::BYPASS_PARAM].presence
    rescue StandardError
      nil
    end

    def stored_token(request)
      request.cookies[MaintenanceMode::BYPASS_COOKIE].presence ||
        request.get_header(MaintenanceMode::BYPASS_HEADER).presence
    rescue StandardError
      nil
    end

    def grant_bypass(request)
      headers = {
        "content-type" => "text/plain; charset=utf-8",
        "cache-control" => "no-store",
        "location" => url_without_token(request)
      }

      Rack::Utils.set_cookie_header!(
        headers,
        MaintenanceMode::BYPASS_COOKIE,
        value: MaintenanceMode.bypass_token,
        path: "/",
        max_age: MaintenanceMode::BYPASS_TTL,
        httponly: true,
        same_site: :lax,
        secure: request.ssl?
      )

      [302, headers, ["Maintenance bypass granted."]]
    end

    def clear_bypass
      headers = { "content-type" => "text/plain; charset=utf-8", "location" => "/" }
      Rack::Utils.delete_cookie_header!(headers, MaintenanceMode::BYPASS_COOKIE, path: "/")
      [302, headers, ["Maintenance bypass cleared."]]
    end

    def url_without_token(request)
      params = Rack::Utils.parse_nested_query(request.query_string)
      params.delete(MaintenanceMode::BYPASS_PARAM)
      query = Rack::Utils.build_nested_query(params)

      query.empty? ? request.path : "#{request.path}?#{query}"
    rescue StandardError
      request.path
    end

    def json_request?(request)
      request.path.start_with?("/api/") ||
        request.path.end_with?(".json") ||
        request.params["format"] == "json" ||
        request.get_header("HTTP_ACCEPT").to_s.include?("application/json")
    rescue StandardError
      false
    end

    def html_response
      body = page_html
      [503, base_headers.merge("content-type" => "text/html; charset=utf-8",
                               "content-length" => body.bytesize.to_s), [body]]
    end

    def json_response
      body = {
        status: "maintenance",
        maintenance: true,
        message: MaintenanceMode.message,
        eta: MaintenanceMode.eta,
        started_at: MaintenanceMode.started_at
      }.compact.to_json

      [503, base_headers.merge("content-type" => "application/json; charset=utf-8",
                               "content-length" => body.bytesize.to_s), [body]]
    end

    def base_headers
      {
        "cache-control" => "no-store, no-cache, must-revalidate",
        "retry-after" => MaintenanceMode.retry_after.to_s
      }
    end

    def page_html
      path = Rails.root.join(HTML_PATH)
      stamp = [File.mtime(path).to_i, File.size(path)]
      return @html if defined?(@html) && @html_stamp == stamp

      @html_stamp = stamp
      @html = File.read(path)
    rescue SystemCallError
      "<!doctype html><title>Under maintenance</title>" \
        "<h1>QUL is under maintenance</h1><p>#{Rack::Utils.escape_html(MaintenanceMode.message)}</p>"
    end
  end
end
