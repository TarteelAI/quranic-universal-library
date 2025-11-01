module Api
  module V1
    class ResourcesController < ApiController
      def index
        render_json(@presenter.resources)
      end

      def show
        render_json(@presenter.resource)
      end

      protected
      def init_presenter
        @presenter = ::V1::ResourcePresenter.new(self)
      end
    end
  end
end