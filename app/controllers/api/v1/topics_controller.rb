module Api
  module V1
    class TopicsController < ApiController
      def index
        render_json(@presenter.topics)
      end

      def show
        render_json(@presenter.topic)
      end

      protected
      def init_presenter
        @presenter = ::V1::TopicPresenter.new(self)
      end
    end
  end
end