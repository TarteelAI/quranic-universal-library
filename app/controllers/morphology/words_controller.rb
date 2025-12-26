module Morphology
  class WordsController < ApplicationController
    def show
    end

    protected
    def init_presenter
      @presenter = Morphology::WordPresenter.new(self)
    end
  end
end


