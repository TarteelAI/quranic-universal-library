module Api
  module V1
    class ResourcesController < ApiController
      def translations
      end

      def tafsirs
      end

      def languages
      end

      private

      def init_presenter
        @presenter = ::V1::ResourcesPresenter.new(self)
      end
    end
  end
end

