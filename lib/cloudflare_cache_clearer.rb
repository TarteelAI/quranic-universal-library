require 'net/http'
require 'uri'
require 'json'

=begin
# Usage

client = CloudflareCacheClearer.new()
client.clear_cache(urls: ["https://static-cdn.tarteel.ai/translations/ar-tafsir-tabari-1742145512.json"])
=end


class CloudflareCacheClearer
  BASE_URL = "https://api.cloudflare.com/client/v4"

  def initialize(api_token: ENV['CLOUDFLARE_API_KEY'], zone_id: ENV['CLOUDFLARE_ZONE_ID'])
    @api_token = api_token
    @zone_id = zone_id
  end

  def clear_cache(urls:)
    uri = URI("#{BASE_URL}/zones/#{@zone_id}/purge_cache")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_token}"
    request["Content-Type"] = "application/json"
    request.body = { files: urls }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end
end