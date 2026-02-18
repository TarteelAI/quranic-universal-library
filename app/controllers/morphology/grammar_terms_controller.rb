module Morphology
  class GrammarTermsController < ApplicationController
    def show
      @locale = params[:locale].presence || I18n.locale.to_s
      @category = params[:category].to_s
      @term = params[:term].to_s

      @grammar_term = Morphology::GrammarTerm.find_by!(category: @category, term: @term)
      @translation = @grammar_term.translation_for(@locale)
      @title = @translation&.title.presence
      @description = @translation&.description.presence
    end
  end
end

