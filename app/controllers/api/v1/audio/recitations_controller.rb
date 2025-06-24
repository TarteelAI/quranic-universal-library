module Api::V1
  module Audio
    class RecitationsController < ApiController
      def surah_recitations; end

      def ayah_recitations; end

      protected

      def init_presenter
        @presenter = ::V1::Audio::RecitationPresenter.new(params)
      end
    end
  end
end