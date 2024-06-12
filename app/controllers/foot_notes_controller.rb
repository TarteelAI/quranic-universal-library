class FootNotesController < ApplicationController
  def show
    @foot_note = if params[:draft] == 'true'
                   Draft::FootNote.find_by(id: params[:id])
                 end

    @foot_note ||= FootNote.find(params[:id])

    render layout: false
  end
end