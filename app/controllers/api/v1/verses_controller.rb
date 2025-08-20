module Api
  module V1
    class VersesController < ApiController
      def select2
        render_json(@presenter.select2)
      end

      def index
        render_json(@presenter.verses)
      end

      protected
      def init_presenter
        @presenter = ::V1::VersePresenter.new(self)
      end
    end
  end
end