module Api
  module V1
    module Morphology
      class StemsController < ApiController
        def index
          render_json(@presenter.stems)
        end

        def show
          render_json(@presenter.stem)
        end

        protected
        def init_presenter
          @presenter = ::V1::Morphology::StemPresenter.new(self)
        end
      end
    end
  end
end