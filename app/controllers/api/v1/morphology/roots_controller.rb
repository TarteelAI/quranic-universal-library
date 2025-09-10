module Api
  module V1
    module Morphology
      class RootsController < ApiController
        def index
          render_json(@presenter.roots)
        end

        def show
          render_json(@presenter.root)
        end

        protected
        def init_presenter
          @presenter = ::V1::Morphology::RootPresenter.new(self)
        end
      end
    end
  end
end