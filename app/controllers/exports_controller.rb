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
    per_page = (params[:per_page] || 100).to_i.clamp(1, 1000)
    page = params[:page] || 1

    @pagy, @pages = pagy_array((1..@mushaf.pages_count).to_a, items: per_page, page: page)
  end

  protected

  # Only text and glyph columns can be rendered by the export views
  def export_script?(name)
    name = name.to_s
    name.match?(/\A(text|code)_[a-z0-9_]+\z/) && (Word.column_names.include?(name) || Verse.column_names.include?(name))
  end

  def set_defaults
    params[:word] ||= '1:1:1'
    params[:ayah] ||= '1:1'
    params[:script] = 'code_v1' unless export_script?(params[:script])
    params[:font_size] = (params[:font_size].presence || 36).to_i.clamp(8, 200).to_s
    params[:mushaf_id] ||= 1
    params[:page_number] ||= 1
  end
end