module Api
  module V1
    class ChaptersController < ApiController
      def index
        render_json(@presenter.chapters)
      end

      def show
        render_json(@presenter.chapter)
      end

      private

      def init_presenter
        @presenter = ::V1::ChapterPresenter.new(self)
      end
    end
  end
end