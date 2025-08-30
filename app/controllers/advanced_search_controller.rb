class AdvancedSearchController < ApplicationController
  before_action :set_search_params, only: [:index, :search]

  def index
    # Show the advanced search form
  end

  def search
    @search_service = Search::AdvancedSearchService.new(@search_params[:query], search_options)
    @search_result = @search_service.search

    respond_to do |format|
      format.html { render :results }
      format.turbo_stream { render :results }
      format.json { render json: format_api_response(@search_result) }
    end
  rescue => e
    Rails.logger.error "Advanced search error: #{e.message}"
    
    @search_result = {
      type: 'error',
      query: @search_params[:query],
      verses: [],
      total_count: 0,
      error: 'Search failed. Please try again.'
    }

    respond_to do |format|
      format.html { render :results }
      format.turbo_stream { render :results }
      format.json { render json: { error: 'Search failed', message: e.message }, status: :internal_server_error }
    end
  end

  private

  def set_search_params
    @search_params = params.permit(:query, :type, :chapter_id, :script, :morphology_category, 
                                  :translation_language, :include_translations, :include_tafsirs,
                                  verse_range: [])
  end

  def search_options
    options = @search_params.except(:query).to_h
    
    # Convert string booleans to actual booleans
    options[:include_translations] = ActiveModel::Type::Boolean.new.cast(options[:include_translations])
    options[:include_tafsirs] = ActiveModel::Type::Boolean.new.cast(options[:include_tafsirs])
    
    options.compact
  end

  def format_api_response(result)
    {
      search: {
        type: result[:type],
        query: result[:query],
        filters: result[:filters] || {},
        total_count: result[:total_count] || 0,
        execution_time: Time.current.to_f
      },
      data: {
        verses: result[:verses] || [],
        translations: result[:translations] || [],
        tafsirs: result[:tafsirs] || [],
        morphology_words: result[:morphology_words] || [],
        breakdown: result[:breakdown] || {}
      }
    }
  end
end