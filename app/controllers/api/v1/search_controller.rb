class Api::V1::SearchController < Api::V1::ApiController
  before_action :validate_search_params, only: [:advanced_search]

  # POST /api/v1/search/advanced
  def advanced_search
    search_service = Search::AdvancedSearchService.new(search_params[:query], search_options)
    result = search_service.search

    render json: format_search_response(result), status: :ok
  rescue => e
    render json: { error: 'Search failed', message: e.message }, status: :internal_server_error
  end

  # GET /api/v1/search/morphology_categories
  def morphology_categories
    categories = [
      { value: 'noun', label: 'Noun (اسم)', description: 'Names of persons, places, things' },
      { value: 'verb', label: 'Verb (فعل)', description: 'Action words' },
      { value: 'particle', label: 'Particle (حرف)', description: 'Connecting words' },
      { value: 'pronoun', label: 'Pronoun (ضمير)', description: 'Substitute words for nouns' },
      { value: 'proper_noun', label: 'Proper Noun', description: 'Names of specific entities' },
      { value: 'adjective', label: 'Adjective', description: 'Descriptive words' }
    ]

    render json: { categories: categories }
  end

  # GET /api/v1/search/arabic_scripts
  def arabic_scripts
    scripts = [
      { value: 'qpc_hafs', label: 'QPC Hafs', description: 'Quran Printing Complex - Hafs recitation' },
      { value: 'uthmani', label: 'Uthmani', description: 'Traditional Uthmani script' },
      { value: 'imlaei', label: 'Imlaei', description: 'Modern Arabic script' },
      { value: 'indopak', label: 'Indo-Pak', description: 'Indo-Pakistani script style' },
      { value: 'qpc_nastaleeq', label: 'QPC Nastaleeq', description: 'QPC Nastaleeq font' },
      { value: 'uthmani_simple', label: 'Uthmani Simple', description: 'Simplified Uthmani without diacritics' }
    ]

    render json: { scripts: scripts }
  end

  # GET /api/v1/search/suggestions?q=query
  def suggestions
    query = params[:q].to_s.strip
    return render json: { suggestions: [] } if query.blank?

    suggestions = {
      roots: search_roots(query),
      lemmas: search_lemmas(query),
      stems: search_stems(query),
      verses: search_verse_keys(query)
    }

    render json: { suggestions: suggestions }
  end

  private

  def search_params
    params.require(:search).permit(:query, :type, :chapter_id, :script, :morphology_category, 
                                  :translation_language, :include_translations, :include_tafsirs,
                                  verse_range: [])
  end

  def search_options
    options = search_params.except(:query).to_h
    
    # Convert string booleans to actual booleans
    options[:include_translations] = ActiveModel::Type::Boolean.new.cast(options[:include_translations])
    options[:include_tafsirs] = ActiveModel::Type::Boolean.new.cast(options[:include_tafsirs])
    
    options
  end

  def validate_search_params
    if params[:search].blank? || params[:search][:query].blank?
      render json: { error: 'Query parameter is required' }, status: :bad_request
      return
    end

    if params[:search][:type].present? && !valid_search_types.include?(params[:search][:type])
      render json: { error: 'Invalid search type' }, status: :bad_request
      return
    end

    if params[:search][:script].present? && !valid_scripts.include?(params[:search][:script])
      render json: { error: 'Invalid script type' }, status: :bad_request
      return
    end
  end

  def valid_search_types
    %w[text morphology semantic root lemma stem pattern script_specific combined]
  end

  def valid_scripts
    %w[qpc_hafs uthmani imlaei indopak qpc_nastaleeq uthmani_simple]
  end

  def format_search_response(result)
    {
      search: {
        type: result[:type],
        query: result[:query],
        filters: result[:filters] || {},
        total_count: result[:total_count] || 0,
        execution_time: Time.current.to_f
      },
      data: {
        verses: format_verses(result[:verses] || []),
        translations: format_translations(result[:translations] || []),
        tafsirs: format_tafsirs(result[:tafsirs] || []),
        morphology_words: format_morphology_words(result[:morphology_words] || []),
        breakdown: result[:breakdown] || {}
      }
    }
  end

  def format_verses(verses)
    verses.map do |verse|
      {
        id: verse.id,
        verse_key: verse.verse_key,
        verse_number: verse.verse_number,
        chapter_id: verse.chapter_id,
        text_qpc_hafs: verse.text_qpc_hafs,
        text_uthmani: verse.text_uthmani,
        text_imlaei: verse.text_imlaei,
        translations: verse.translations.limit(3).map { |t| format_translation(t) },
        words_count: verse.words_count
      }
    end
  end

  def format_translations(translations)
    translations.map { |t| format_translation(t) }
  end

  def format_translation(translation)
    {
      id: translation.id,
      text: translation.text,
      language_name: translation.language_name,
      language_id: translation.language_id,
      resource_name: translation.resource_name,
      verse_key: translation.verse_key
    }
  end

  def format_tafsirs(tafsirs)
    tafsirs.map do |tafsir|
      {
        id: tafsir.id,
        text: tafsir.text.truncate(500),
        language_name: tafsir.language_name,
        resource_name: tafsir.resource_name,
        verse_key: tafsir.verse_key
      }
    end
  end

  def format_morphology_words(morphology_words)
    morphology_words.map do |morph_word|
      {
        id: morph_word.id,
        location: morph_word.location,
        description: morph_word.description,
        word_text: morph_word.word.text_qpc_hafs,
        verse_key: morph_word.verse.verse_key,
        grammar_concepts: morph_word.grammar_concepts.map(&:name)
      }
    end
  end

  def search_roots(query)
    Root.where("text_uthmani ILIKE ? OR text_clean ILIKE ?", "%#{query}%", "%#{query}%")
        .limit(10)
        .pluck(:id, :text_uthmani, :english_trilateral)
        .map { |id, text, english| { id: id, text: text, english: english, type: 'root' } }
  end

  def search_lemmas(query)
    Lemma.where("text_madani ILIKE ? OR text_clean ILIKE ?", "%#{query}%", "%#{query}%")
         .limit(10)
         .pluck(:id, :text_madani)
         .map { |id, text| { id: id, text: text, type: 'lemma' } }
  end

  def search_stems(query)
    Stem.where("text_madani ILIKE ? OR text_clean ILIKE ?", "%#{query}%", "%#{query}%")
        .limit(10)
        .pluck(:id, :text_madani)
        .map { |id, text| { id: id, text: text, type: 'stem' } }
  end

  def search_verse_keys(query)
    # Look for verse key patterns like "2:255" or "Al-Baqarah:255"
    if query.match?(/\d+:\d+/)
      verse = Verse.find_by(verse_key: query)
      return [{ id: verse.id, verse_key: verse.verse_key, type: 'verse' }] if verse
    end

    []
  end
end