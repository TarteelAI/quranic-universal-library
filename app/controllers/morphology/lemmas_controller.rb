module Morphology
  class LemmasController < ApplicationController
    def show
      @lemma = Lemma.find_by!(text_clean: params[:id])
    end
  end
end