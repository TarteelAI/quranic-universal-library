module Api
  module V1
    class ChaptersController < ApiController
      def index
      end

      def show
      end

      private

      def init_presenter
        @presenter = ::V1::ChapterPresenter.new(self)
      end
    end
  end
end