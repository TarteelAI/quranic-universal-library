# This script downloads and converts MP3 recitations
#
# Usage:
#   ruby download_audio.rb --reciter 201
#

require 'optparse'
require 'fileutils'
require 'net/http'
require 'uri'
require 'json'
require 'open3'

# CLI option parsing
options = {
  chapters: (1..114).to_a
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby download_audio.rb [options]"

  opts.on("-r", "--reciter ID", Integer, "Reciter ID (required)") do |v|
    options[:reciter_id] = v
  end

  opts.on("-c", "--chapters RANGE", String, "Comma-separated ids of surah, range, or both (e.g. 1,3,5 or 1..3,5). Default: all surahs (1..114)") do |v|
    options[:chapters] = v.split(',').flat_map do |part|
      if part =~ /^(\d+)\.\.(\d+)$/
        Range.new($1.to_i, $2.to_i).to_a
      else
        [part.to_i]
      end
    end.uniq.sort
  end

  opts.on("-h", "--help", "Show help") do
    puts opts
    exit
  end
end.parse!

unless options[:reciter_id]
  puts "Error: --reciter is required\n\n"
  puts "Use -h or --help for usage instructions."
  exit 1
end

# Helpers
def fetch_reciter_and_audio_files(reciter_id)
  uri = URI("https://qul.tarteel.ai/api/v1/audio/surah_recitations/#{reciter_id}?v=#{Time.now.to_i}")
  response = Net::HTTP.get_response(uri)
  unless response.is_a?(Net::HTTPSuccess)
    abort "Failed to fetch audio files from #{uri} (HTTP #{response.code})"
  end

  data = JSON.parse(response.body)
  reciter_name = data.dig("recitation", "name") || "Unknown"
  audio_files = data.dig("recitation", "audio_files") || {}
  [reciter_name, audio_files]
end

def download_audio(url, destination_file, format)
  return puts "#{File.basename(destination_file)} already exists" if File.exist?(destination_file)
  url = url.gsub("mp3", format)

  uri = URI(url)
  Net::HTTP.version_1_2
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  response = http.get(uri.path)

  if response.is_a?(Net::HTTPSuccess)
    File.open(destination_file, "wb") { |file| file.write(response.body) }
    puts "Downloaded #{url}"
  else
    puts "Failed to download #{url} (HTTP #{response.code})"
  end
end

reciter_id = options[:reciter_id]
chapters = options[:chapters]

base_path = "./data/audio/#{reciter_id}/wav"
mp3_path = "#{base_path}"
FileUtils.mkdir_p(mp3_path)

puts "Fetching audio files for reciter ID #{reciter_id}..."
reciter_name, audio_files = fetch_reciter_and_audio_files(reciter_id)

chapters.each do |i|
  file_info = audio_files[i.to_s]
  unless file_info
    puts "Surah #{i}: No audio file info found, skipping"
    next
  end

  padded = i.to_s.rjust(3, '0')
  mp3_file = "#{mp3_path}/#{padded}.wav"
  audio_url = file_info["audio_url"]

  puts "\n=== Surah #{i} - #{reciter_name} ==="
  puts "URL:     #{audio_url}"
  puts "WAV:     #{mp3_file}"

  download_audio(audio_url, mp3_file, 'wav')
end