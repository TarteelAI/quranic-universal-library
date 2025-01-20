module Api
  module V1
    class VersesController < ApiController
      def by_chapter
        render_verses(chapter_id: params[:chapter_number])
      end

      def by_juz
        render_verses(juz_number: params[:juz_number])
      end

      def by_hizb
        render_verses(hizb_number: params[:hizb_number])
      end

      def by_rub()
        render_verses(rub_el_hizb_number: params[:rub_el_hizb_number])
      end

      def by_ruku
        render_verses(ruku_number: params[:ruku_number])
      end

      def by_manzil
        render_verses(manzil_number: params[:manzil_number])
      end

      def random
      end

      protected

      def init_presenter
        @presenter = ::V1::VersePresenter.new(params)
      end

      def render_verses(filters)
        @presenter.set_filters(filters)
        render 'index'
      end
    end
  end
end
