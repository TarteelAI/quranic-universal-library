module Api
  module V1
    class TranslationsController < ApiController
      def index
        render_json(@presenter.translations)
      end

      def show
        render_json(@presenter.translation)
      end

      protected
      def init_presenter
        @presenter = ::V1::TranslationPresenter.new(self)
      end
    end
  end
end