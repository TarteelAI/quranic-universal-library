class SearchController < ApplicationController
  DEFAULT_SCRIPT = 'text_qpc_hafs'

  def index
    @query = params[:q].to_s.strip
    @exact = params[:exact] == '1'
    @across = params[:across] == '1'
    @script = allowed_script(params[:script])
    @searched = @query.length >= Search::QuranText::MIN_QUERY_LENGTH

    return unless @searched

    @search = Search::QuranText.new(query: @query, exact: @exact, across: @across)
    @pagy, @verses = pagy(@search.ordered)
  end

  protected

  def allowed_script(script)
    return DEFAULT_SCRIPT if script.blank?

    SearchHelper::DISPLAY_SCRIPTS.to_h.key?(script) ? script : DEFAULT_SCRIPT
  end
end
