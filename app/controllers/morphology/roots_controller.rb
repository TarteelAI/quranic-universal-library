module Morphology
  class RootsController < ApplicationController
    def show
      @root = Root.find_by!(arabic_trilateral: params[:id])
    end
  end
end