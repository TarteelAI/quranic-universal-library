module Api
  module V1
    class VersesController < ApiController
      def index
      end

      protected
      def init_presenter
        @presenter = ::V1::VersePresenter.new(params)
      end
    end
  end
end