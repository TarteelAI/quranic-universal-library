module Api::V1
  module Audio
    class TranscriptsController < ApiController
      def surah_transcript; end

      protected

      def init_presenter
        @presenter = ::V1::Audio::TranscriptPresenter.new(self)
      end
    end
  end
end
