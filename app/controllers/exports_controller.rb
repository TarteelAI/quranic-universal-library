class ExportsController < ApplicationController
  layout 'export'
  before_action :set_defaults

  def word
    @word = if params[:word].include?(':')
              Word.find_by(location: params[:word])
            else
              Word.find_by(word_index: params[:word])
            end
  end

  def ayah
    @verse = if params[:ayah].include?(':')
               Verse.find_by(verse_key: params[:ayah])
            else
              Verse.find_by(verse_index: params[:ayah])
            end
  end

  def mushaf_page
    @mushaf = Mushaf.find(params[:mushaf_id])

    @words = MushafWord.where(
      mushaf_id: params[:mushaf_id],
      page_number: params[:page_number]
    ).order('position_in_page ASC')
  end

  def mushaf
    @mushaf = Mushaf.find(params[:mushaf_id])
  end

  protected

  def set_defaults
    params[:word] ||= '1:1:1'
    params[:ayah] ||= '1:1'
    params[:script] ||= 'code_v1'
    params[:font_size] ||= '36'
    params[:mushaf_id] ||= 1
    params[:page_number] ||= 1
  end
end