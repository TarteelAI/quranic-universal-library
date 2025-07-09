module Morphology
  class StemsController < ApplicationController
    def show
      @stem = Stem.find_by!(text_clean: params[:id])
    end
  end
end