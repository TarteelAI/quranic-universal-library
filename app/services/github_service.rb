require 'net/http'

class GithubService
  GITHUB_API_BASE = 'https://api.github.com'
  REPO_OWNER = 'TarteelAI'
  REPO_NAME = 'quranic-universal-library'
  FALLBACK_CONTRIBUTORS = 30
  FAILURE_EXPIRES_IN = 5.minutes
  
  class << self
    def fetch_contributors(limit: 20)
      key = "github_contributors_#{limit}"
      cached = Rails.cache.read(key)
      return cached if cached

      # A failed request is kept as an empty list for a few minutes, so an outage or a rate limit
      # costs one slow request, not one for every page.
      contributors = request_contributors(limit)
      Rails.cache.write(key, contributors || [], expires_in: contributors ? 1.hour : FAILURE_EXPIRES_IN)
      contributors || []
    end

    # The repository's contributors, bots left out (GitHub lists at most 100 on one page), or the
    # count on 2026-11-20 when GitHub cannot be reached (as lib/github.ts does for the stars).
    # Without a cache (development and test) GitHub is not asked: every page would ask it.
    def contributors_count
      return FALLBACK_CONTRIBUTORS if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

      fetch_contributors(limit: 100).size.nonzero? || FALLBACK_CONTRIBUTORS
    end

    def clear_cache
      Rails.cache.delete_matched("github_contributors_*")
    end

    private

    # The contributors as GitHub lists them, bots left out, or nil when the request fails.
    def request_contributors(limit)
      response = make_request("/repos/#{REPO_OWNER}/#{REPO_NAME}/contributors?per_page=#{limit}")
      raise "#{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      Oj.safe_load(response.body).reject { |contributor| contributor['type'] == 'Bot' }.map do |contributor|
        contributor.slice('login', 'avatar_url', 'html_url', 'contributions', 'type').symbolize_keys
          .merge(name: contributor['name'] || contributor['login'])
      end
    rescue StandardError => e
      Rails.logger.error "Error fetching GitHub contributors: #{e.message}"
      nil
    end

    def make_request(path)
      uri = URI("#{GITHUB_API_BASE}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      # A page waits on this request, so a slow GitHub costs seconds, not a minute, and is not asked twice.
      http.open_timeout = 2
      http.read_timeout = 3
      http.max_retries = 0
      
      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/vnd.github.v3+json'
      request['User-Agent'] = 'Quranic-Universal-Library'
      
      # Add GitHub token if available for higher rate limits
      if Rails.application.credentials.github&.token
        request['Authorization'] = "token #{Rails.application.credentials.github.token}"
      end
      
      http.request(request)
    end
  end
end
