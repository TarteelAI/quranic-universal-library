# frozen_string_literal: true

class Api::V1::SearchController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :authenticate_api_client
  before_action :validate_search_params, only: [:general_search, :morphology_search, :semantic_search, :script_search]
  before_action :set_pagination_params

  # General search across verses, translations, and words
  def general_search
    query = params[:q]&.strip
    
    if query.blank?
      render json: { error: 'Query parameter is required' }, status: :bad_request
      return
    end

    results = perform_general_search(query)
    
    render json: {
      query: query,
      total_results: results[:total],
      results: results[:data],
      pagination: pagination_info(results[:total]),
      suggestions: results[:suggestions],
      search_time: results[:search_time]
    }
  end

  # Morphology-based search for grammatical attributes
  def morphology_search
    filters = morphology_filters
    
    if filters.empty?
      render json: { error: 'At least one morphology filter is required' }, status: :bad_request
      return
    end

    results = perform_morphology_search(filters)
    
    render json: {
      filters: filters,
      total_results: results[:total],
      results: results[:data],
      pagination: pagination_info(results[:total]),
      search_time: results[:search_time]
    }
  end

  # Semantic search using embeddings and conceptual similarity
  def semantic_search
    query = params[:q]&.strip
    
    if query.blank?
      render json: { error: 'Query parameter is required' }, status: :bad_request
      return
    end

    results = perform_semantic_search(query)
    
    render json: {
      query: query,
      search_type: 'semantic',
      total_results: results[:total],
      results: results[:data],
      pagination: pagination_info(results[:total]),
      similarity_threshold: results[:threshold],
      search_time: results[:search_time]
    }
  end

  # Arabic script-specific search (with diacritic handling)
  def script_search
    query = params[:q]&.strip
    script_type = params[:script_type] || 'uthmani'
    
    if query.blank?
      render json: { error: 'Query parameter is required' }, status: :bad_request
      return
    end

    results = perform_script_search(query, script_type)
    
    render json: {
      query: query,
      script_type: script_type,
      total_results: results[:total],
      results: results[:data],
      pagination: pagination_info(results[:total]),
      search_time: results[:search_time]
    }
  end

  # Autocomplete suggestions
  def autocomplete
    query = params[:q]&.strip
    
    if query.blank? || query.length < 2
      render json: { suggestions: [] }
      return
    end

    suggestions = generate_autocomplete_suggestions(query)
    
    render json: {
      query: query,
      suggestions: suggestions
    }
  end

  private

  def authenticate_api_client
    api_key = request.headers['X-API-Key'] || params[:api_key]
    
    if api_key.blank?
      render json: { error: 'API key required' }, status: :unauthorized
      return
    end

    @api_client = ApiClient.find_by(api_key: api_key, active: true)
    
    unless @api_client
      render json: { error: 'Invalid API key' }, status: :unauthorized
      return
    end

    # Rate limiting check
    if @api_client.rate_limit_exceeded?
      render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
      return
    end

    @api_client.increment_request_count!
  end

  def validate_search_params
    if params[:per_page].present? && params[:per_page].to_i > 100
      render json: { error: 'Maximum 100 results per page allowed' }, status: :bad_request
      return
    end
  end

  def set_pagination_params
    @page = [params[:page].to_i, 1].max
    @per_page = [[params[:per_page].to_i, 20].max, 100].min
  end

  def perform_general_search(query)
    start_time = Time.current
    
    # Search across multiple models
    verse_results = Verse.elasticsearch_search(query, 
      page: @page, 
      per_page: @per_page,
      filters: search_filters
    )
    
    translation_results = Translation.elasticsearch_search(query,
      page: @page,
      per_page: @per_page, 
      filters: search_filters
    )

    # Combine and rank results
    combined_results = combine_search_results(verse_results, translation_results)
    suggestions = extract_suggestions(verse_results)
    
    {
      data: format_general_results(combined_results),
      total: combined_results.count,
      suggestions: suggestions,
      search_time: ((Time.current - start_time) * 1000).round(2)
    }
  end

  def perform_morphology_search(filters)
    start_time = Time.current
    
    results = Word.morphology_search(filters)
    
    {
      data: format_morphology_results(results),
      total: results.count,
      search_time: ((Time.current - start_time) * 1000).round(2)
    }
  end

  def perform_semantic_search(query)
    start_time = Time.current
    
    # Use semantic search with conceptual boosting
    results = Verse.semantic_search(query,
      page: @page,
      per_page: @per_page,
      filters: search_filters
    )
    
    {
      data: format_semantic_results(results),
      total: results.count,
      threshold: 0.7, # Configurable similarity threshold
      search_time: ((Time.current - start_time) * 1000).round(2)
    }
  end

  def perform_script_search(query, script_type)
    start_time = Time.current
    
    search_field = case script_type
                  when 'uthmani' then 'text_uthmani'
                  when 'qpc_hafs' then 'text_qpc_hafs'
                  when 'indopak' then 'text_indopak'
                  else 'text_uthmani'
                  end

    results = Verse.search(query,
      fields: [search_field],
      page: @page,
      per_page: @per_page,
      highlight: { fields: { search_field => {} } },
      where: search_filters
    )
    
    {
      data: format_script_results(results, script_type),
      total: results.count,
      search_time: ((Time.current - start_time) * 1000).round(2)
    }
  end

  def generate_autocomplete_suggestions(query)
    # Get suggestions from verse text and translations
    verse_suggestions = Verse.search(query, 
      fields: ['text_uthmani_simple', 'text_imlaei_simple'],
      limit: 5,
      suggest: [:text]
    ).suggestions

    translation_suggestions = Translation.search(query,
      fields: ['text'],
      limit: 5,
      suggest: [:text]
    ).suggestions

    # Combine and format suggestions
    all_suggestions = (verse_suggestions + translation_suggestions)
                     .map { |s| s['text'] }
                     .uniq
                     .first(10)

    all_suggestions.map do |suggestion|
      {
        text: suggestion,
        type: 'suggestion'
      }
    end
  end

  def search_filters
    filters = {}
    filters[:chapter_id] = params[:chapter_id] if params[:chapter_id].present?
    filters[:juz_number] = params[:juz_number] if params[:juz_number].present?
    filters[:hizb_number] = params[:hizb_number] if params[:hizb_number].present?
    filters[:language_id] = params[:language_id] if params[:language_id].present?
    filters
  end

  def morphology_filters
    filters = {}
    filters[:part_of_speech] = params[:part_of_speech] if params[:part_of_speech].present?
    filters[:pos_tags] = params[:pos_tags] if params[:pos_tags].present?
    filters[:root] = params[:root] if params[:root].present?
    filters[:lemma] = params[:lemma] if params[:lemma].present?
    filters[:grammar_role] = params[:grammar_role] if params[:grammar_role].present?
    filters[:verb_form] = params[:verb_form] if params[:verb_form].present?
    filters
  end

  def combine_search_results(verse_results, translation_results)
    # Simple combination - in production, would implement more sophisticated ranking
    verse_results.to_a + translation_results.to_a
  end

  def extract_suggestions(results)
    return [] unless results.respond_to?(:suggestions)
    
    results.suggestions.map do |suggestion|
      {
        text: suggestion['text'],
        confidence: suggestion['score'] || 1.0
      }
    end
  end

  def format_general_results(results)
    results.map do |result|
      case result
      when Verse
        format_verse_result(result)
      when Translation
        format_translation_result(result)
      else
        format_generic_result(result)
      end
    end
  end

  def format_verse_result(verse)
    {
      type: 'verse',
      id: verse.id,
      verse_key: verse.verse_key,
      chapter_id: verse.chapter_id,
      verse_number: verse.verse_number,
      text_uthmani: verse.text_uthmani,
      text_qpc_hafs: verse.text_qpc_hafs,
      text_simple: verse.text_uthmani_simple,
      juz_number: verse.juz_number,
      hizb_number: verse.hizb_number,
      page_number: verse.page_number,
      highlighted_text: extract_highlights(verse),
      translations: verse.translations.limit(3).map do |t|
        {
          id: t.id,
          text: t.text,
          language_name: t.language&.name,
          resource_name: t.resource_name
        }
      end
    }
  end

  def format_translation_result(translation)
    {
      type: 'translation',
      id: translation.id,
      verse_key: translation.verse_key,
      chapter_id: translation.chapter_id,
      verse_number: translation.verse_number,
      text: translation.text,
      language_name: translation.language&.name,
      resource_name: translation.resource_name,
      highlighted_text: extract_highlights(translation),
      verse_text: {
        uthmani: translation.verse&.text_uthmani,
        qpc_hafs: translation.verse&.text_qpc_hafs
      }
    }
  end

  def format_morphology_results(results)
    results.map do |word|
      {
        type: 'word',
        id: word.id,
        verse_key: word.verse_key,
        position: word.position,
        text_uthmani: word.text_uthmani,
        text_qpc_hafs: word.text_qpc_hafs,
        root_name: word.root&.value,
        lemma_name: word.lemma&.text_clean,
        morphology: word.morphology_word_segments.map do |segment|
          {
            part_of_speech: segment.part_of_speech_key,
            pos_tags: segment.pos_tags,
            grammar_role: segment.grammar_role,
            verb_form: segment.verb_form
          }
        end,
        translations: word.word_translations.limit(3).map do |t|
          {
            text: t.text,
            language_name: t.language&.name
          }
        end
      }
    end
  end

  def format_semantic_results(results)
    results.map do |verse|
      verse_data = format_verse_result(verse)
      verse_data[:similarity_score] = verse.try(:_score) || 1.0
      verse_data[:semantic_context] = extract_semantic_context(verse)
      verse_data
    end
  end

  def format_script_results(results, script_type)
    results.map do |verse|
      script_field = "text_#{script_type}"
      
      {
        type: 'verse',
        id: verse.id,
        verse_key: verse.verse_key,
        chapter_id: verse.chapter_id,
        verse_number: verse.verse_number,
        script_type: script_type,
        text: verse.send(script_field),
        highlighted_text: extract_highlights(verse),
        alternative_scripts: {
          uthmani: verse.text_uthmani,
          qpc_hafs: verse.text_qpc_hafs,
          indopak: verse.text_indopak
        }
      }
    end
  end

  def format_generic_result(result)
    {
      type: result.class.name.downcase,
      id: result.id,
      text: result.to_s
    }
  end

  def extract_highlights(result)
    return {} unless result.respond_to?(:search_highlights)
    
    result.search_highlights || {}
  end

  def extract_semantic_context(verse)
    # Extract semantic keywords and themes
    {
      topics: verse.words.joins(:topic).limit(5).pluck('topics.name').compact,
      roots: verse.words.joins(:root).limit(10).pluck('roots.value').compact,
      word_count: verse.words_count
    }
  end

  def pagination_info(total)
    {
      current_page: @page,
      per_page: @per_page,
      total_pages: (total.to_f / @per_page).ceil,
      total_results: total,
      has_next_page: @page < (total.to_f / @per_page).ceil,
      has_prev_page: @page > 1
    }
  end
end