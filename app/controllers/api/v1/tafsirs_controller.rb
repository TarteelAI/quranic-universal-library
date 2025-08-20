module Api
  module V1
    class TafsirsController < ApiController
      def index
        render_json(@presenter.tafsirs)
      end

      def show
        render_json(@presenter.tafsir)
      end

      protected
      def init_presenter
        @presenter = ::V1::TafsirPresenter.new(self)
      end
    end
  end
end