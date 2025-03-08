require 'net/http'
require 'uri'
require 'json'

=begin
# Usage

client = CloudflareCacheClearer.new(

)
Verse.order('verse_index asc').each do |v|
url ="https://audio-cdn.tarteel.ai/quran/alnufais/#{v.chapter_id.to_s.rjust(3,'0')}#{v.verse_number.to_s.rjust(3,'0')}.mp3"
puts url
client.clear_cache(urls: ["https://audio-cdn.tarteel.ai/quran/alnufais/026139.mp3"])
end
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