class ExportsController < ApplicationController
  layout 'export'
  before_action :set_defaults
  before_action -> { allow_script_for(Word) }, only: :word
  before_action -> { allow_script_for(Verse) }, only: :ayah

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
    per_page = int_param(params[:per_page], 100).clamp(1, 1000)
    page = [int_param(params[:page], 1), 1].max

    @pagy, @pages = pagy_array((1..@mushaf.pages_count).to_a, items: per_page, page: page)
  end

  protected

  # Only text and glyph columns (plus aliases like code_v4) of the model the
  # action renders are allowed, anything else falls back to code_v1.
  def allow_script_for(model)
    script = params[:script].to_s
    allowed = script.match?(/\A(text|code)_[a-z0-9_]+\z/) &&
              (model.column_names.include?(script) || model.attribute_aliases.key?(script))

    params[:script] = 'code_v1' unless allowed
  end

  # Query params can arrive as arrays or hashes; anything that isn't a plain
  # integer string falls back to the default.
  def int_param(value, default)
    return default unless value.is_a?(String) || value.is_a?(Integer)

    Integer(value.to_s, 10, exception: false) || default
  end

  def set_defaults
    params[:word] = params[:word].is_a?(String) && params[:word].presence || '1:1:1'
    params[:ayah] = params[:ayah].is_a?(String) && params[:ayah].presence || '1:1'
    params[:script] = 'code_v1' unless params[:script].is_a?(String)
    params[:font_size] = int_param(params[:font_size].presence, 36).clamp(8, 200).to_s
    params[:mushaf_id] ||= 1
    params[:page_number] ||= 1
  end
end
