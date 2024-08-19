class AyahController < ApplicationController
  def show
    @ayah = Verse.find_by(verse_key: params[:key])

    if request.xhr? || request.format.turbo_stream?
      render layout: false
    end
  end
end