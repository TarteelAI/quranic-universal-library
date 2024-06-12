# frozen_string_literal: true

module Utils
  class Downloader
    def self.download(url, filename)
      downloader = agent
      downloader.pluggable_parser.default = Mechanize::Download
      downloader.get(url).save(filename)
    end

    def self.get(url)
      agent.get(url)
    end

    def self.agent
      require 'mechanize'
      Mechanize.new
    end
  end
end

