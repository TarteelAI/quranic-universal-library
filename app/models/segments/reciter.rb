module Segments
  class Reciter < Base
    def audio_url(surah_number)
      @audio_urls_data ||= fetch_audio_urls
      @audio_urls_data[surah_number.to_i - 1]
    end

    protected
    def fetch_audio_urls
      audio_urls.to_s.split(',').map(&:strip)
    end
  end
end