module Api::V1
  module Audio
    class RecitationsController < ApiController
      def surah_recitations; end
      def surah_recitation_detail; end

      def ayah_recitations; end
      def ayah_recitation_detail; end

      def wav_manifest
      end

      protected

      def init_presenter
        @presenter = ::V1::Audio::RecitationPresenter.new(self)
      end
    end
  end
end