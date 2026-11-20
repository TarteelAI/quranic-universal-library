require 'net/http'

class GithubService
  GITHUB_API_BASE = 'https://api.github.com'
  REPO_OWNER = 'TarteelAI'
  REPO_NAME = 'quranic-universal-library'
  FALLBACK_CONTRIBUTORS = 30
  
  class << self
    def fetch_contributors(limit: 20)
      # A failed request is not cached, so the next page asks again.
      contributors = Rails.cache.fetch("github_contributors_#{limit}", expires_in: 1.hour, skip_nil: true) do
        response = make_request("/repos/#{REPO_OWNER}/#{REPO_NAME}/contributors?per_page=#{limit}")
        
        if response.is_a?(Net::HTTPSuccess)
          contributors = Oj.safe_load(response.body)
          contributors
            .reject { |contributor| contributor['type'] == 'Bot' } # Filter out bot users
            .map do |contributor|
              {
                login: contributor['login'],
                name: contributor['name'] || contributor['login'], # Use real name if available, fallback to login
                avatar_url: contributor['avatar_url'],
                html_url: contributor['html_url'],
                contributions: contributor['contributions'],
                type: contributor['type']
              }
            end
        else
          Rails.logger.error "GitHub API error: #{response.code} - #{response.message}"
          nil
        end
      rescue => e
        Rails.logger.error "Error fetching GitHub contributors: #{e.message}"
        nil
      end
      contributors || []
    end

    # The repository's contributors, bots left out (GitHub lists at most 100 on one page), or the
    # count on 2026-11-20 when GitHub cannot be reached (as lib/github.ts does for the stars).
    def contributors_count
      fetch_contributors(limit: 100).size.nonzero? || FALLBACK_CONTRIBUTORS
    end

    def clear_cache
      Rails.cache.delete_matched("github_contributors_*")
    end

    private

    def make_request(path)
      uri = URI("#{GITHUB_API_BASE}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      # A page waits on this request, so a slow GitHub costs seconds, not a minute.
      http.open_timeout = 2
      http.read_timeout = 3
      
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
