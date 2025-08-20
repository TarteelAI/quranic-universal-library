module Api
  module V1
    module Morphology
      class LemmasController < ApiController
        def index
          render_json(@presenter.lemmas)
        end

        def show
          render_json(@presenter.lemma)
        end

        protected
        def init_presenter
          @presenter = ::V1::Morphology::LemmaPresenter.new(self)
        end
      end
    end
  end
end