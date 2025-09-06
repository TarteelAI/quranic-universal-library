class LearningActivitiesController < ApplicationController
  before_action :parse_ayah_param, only: [:show]

  def index
  end

  def show
  end

  private

  def parse_ayah_param
    return unless params[:ayah].present?

    # Parse ayah parameter in format "1:1" (chapter:verse)
    if params[:ayah].match?(/\A\d+:\d+\z/)
      @filtered_ayah = Verse.find_by(verse_key: params[:ayah].strip)
    end
  end
end
