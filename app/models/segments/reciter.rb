module Segments
  class Reciter < Base
    def audio_url(surah_number)
      file = Audio::ChapterAudioFile.where(
        audio_recitation_id: id,
        chapter_id: surah_number.to_i
      ).first

      file.audio_url if file
    end

    protected
    def fetch_audio_urls
      audio_urls.to_s.split(',').map(&:strip)
    end
  end
end