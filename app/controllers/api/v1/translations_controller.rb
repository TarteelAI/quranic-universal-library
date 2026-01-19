module Api
  module V1
    class TranslationsController < ApiController
      def for_ayah
      end

      def by_range
      end

      def random
      end

      private

      def init_presenter
        @presenter = ::V1::TranslationPresenter.new(self)
      end
    end
  end
end

