class LandingController < ApplicationController
  layout 'devise'

  def home
    @description = 'A comprehensive collection of Quranic digital resources'
  end
end