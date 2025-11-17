module Api
  module V1
    class AyahThemesController < ApiController
      def index
        render_json(@presenter.ayah_themes)
      end

      def show
        render_json(@presenter.ayah_theme)
      end

      protected
      def init_presenter
        @presenter = ::V1::AyahThemePresenter.new(self)
      end
    end
  end
end