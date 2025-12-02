module Api
  module V1
    class TafsirsController < ApiController
      # GET multiple tafsirs for a specific ayah
      def for_ayah
      end

      # Get one tafsir for range of ayahs
      def by_range
      end

      def random
      end

      private

      def init_presenter
        @presenter = ::V1::TafsirPresenter.new(self)
      end
    end
  end
end

