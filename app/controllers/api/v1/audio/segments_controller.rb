module Api::V1
  module Audio
    class SegmentsController < ApiController
      def surah_segments; end
      def ayah_segments;end

      protected
      def init_presenter
        @presenter = ::V1::Audio::SegmentPresenter.new(params)
      end
    end
  end
end