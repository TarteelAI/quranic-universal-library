module Search
  class AdvancedSearchService
    attr_reader :query, :options, :filters

    def initialize(query, options = {})
      @query = query.to_s.strip
      @options = options.with_indifferent_access
      @filters = extract_filters
    end

    # Main search method that routes to appropriate search type
    def search
      return empty_result if query.blank?

      case search_type
      when :text
        text_search
      when :morphology
        morphology_search  
      when :semantic
        semantic_search
      when :root
        root_search
      when :lemma
        lemma_search
      when :stem
        stem_search
      when :pattern
        pattern_search
      when :script_specific
        script_specific_search
      else
        combined_search
      end
    rescue => e
      Rails.logger.error "Advanced search error: #{e.message}"
      error_result(e.message)
    end

    private

    def search_type
      @search_type ||= options[:type]&.to_sym || :combined
    end

    def extract_filters
      {
        chapter_id: options[:chapter_id],
        verse_range: options[:verse_range],
        script: options[:script]&.to_sym,
        morphology_category: options[:morphology_category]&.to_sym,
        translation_language: options[:translation_language],
        include_translations: options[:include_translations] != false,
        include_tafsirs: options[:include_tafsirs] == true
      }.compact
    end

    # Full-text search across Arabic texts and translations
    def text_search
      results = {
        verses: search_verses_text,
        translations: search_translations_text,
        total_count: 0
      }

      if filters[:include_tafsirs]
        results[:tafsirs] = search_tafsirs_text
      end

      results[:total_count] = results.values.map { |v| v.is_a?(Array) ? v.size : 0 }.sum
      format_results(results)
    end

    # Search based on morphological categories (POS)
    def morphology_search
      category = filters[:morphology_category] || parse_morphology_category
      
      morphology_results = Morphology::Word
        .joins(:word, :verse)
        .where("morphology_words.description ILIKE ?", "%#{category}%")
        .includes(:word, :verse, :grammar_concepts)
        .limit(100)

      format_morphology_results(morphology_results)
    end

    # Semantic search using embeddings or similar meaning
    def semantic_search
      # For now, implement basic semantic search by expanding synonyms and related words
      expanded_query = expand_semantic_query(query)
      
      # Search using expanded terms
      text_search_with_query(expanded_query)
    end

    # Search by Arabic root
    def root_search
      roots = Root.where("text_uthmani ILIKE ? OR text_clean ILIKE ?", "%#{query}%", "%#{query}%")
      
      verse_ids = Word.where(root: roots).pluck(:verse_id).uniq
      verses = Verse.where(id: verse_ids).includes(:words, :translations).limit(50)
      
      format_verse_results(verses, highlight_roots: true)
    end

    # Search by lemma
    def lemma_search
      lemmas = Lemma.where("text_madani ILIKE ? OR text_clean ILIKE ?", "%#{query}%", "%#{query}%")
      
      verse_ids = Word.where(lemma: lemmas).pluck(:verse_id).uniq
      verses = Verse.where(id: verse_ids).includes(:words, :translations).limit(50)
      
      format_verse_results(verses, highlight_lemmas: true)
    end

    # Search by stem
    def stem_search
      stems = Stem.where("text_madani ILIKE ? OR text_clean ILIKE ?", "%#{query}%", "%#{query}%")
      
      verse_ids = Word.where(stem: stems).pluck(:verse_id).uniq
      verses = Verse.where(id: verse_ids).includes(:words, :translations).limit(50)
      
      format_verse_results(verses, highlight_stems: true)
    end

    # Pattern search using regex
    def pattern_search
      begin
        script_field = script_field_name
        
        verses = Verse.where("#{script_field} ~ ?", query)
          .includes(:words, :translations)
          .limit(50)
        
        format_verse_results(verses, highlight_pattern: true)
      rescue => e
        error_result("Invalid regular expression: #{e.message}")
      end
    end

    # Script-specific search (different Arabic scripts)
    def script_specific_search
      script = filters[:script] || :qpc_hafs
      script_field = "text_#{script}"
      
      verses = Verse.where("#{script_field} ILIKE ?", "%#{query}%")
        .includes(:words, :translations)
        .limit(50)
      
      format_verse_results(verses, script: script)
    end

    # Combined search across multiple types
    def combined_search
      results = {
        text: text_search[:verses] || [],
        roots: root_search[:verses] || [],
        lemmas: lemma_search[:verses] || [],
        stems: stem_search[:verses] || []
      }

      # Add morphology if query might be a morphological term
      if might_be_morphology_query?
        results[:morphology] = morphology_search[:verses] || []
      end

      # Combine and deduplicate results
      all_verses = combine_and_deduplicate_verses(results)
      
      {
        type: 'combined',
        query: query,
        verses: all_verses,
        total_count: all_verses.size,
        breakdown: results.transform_values(&:size)
      }
    end

    # Helper methods

    def search_verses_text
      script_field = script_field_name
      scope = Verse.includes(:words, :translations)
      
      if filters[:chapter_id]
        scope = scope.where(chapter_id: filters[:chapter_id])
      end
      
      scope.where("#{script_field} ILIKE ?", "%#{query}%").limit(50)
    end

    def search_translations_text
      return [] unless filters[:include_translations]
      
      scope = Translation.includes(:verse)
      
      if filters[:translation_language]
        scope = scope.joins(:language).where(languages: { iso_code: filters[:translation_language] })
      end
      
      if filters[:chapter_id]
        scope = scope.where(chapter_id: filters[:chapter_id])
      end
      
      scope.where("text ILIKE ?", "%#{query}%").limit(50)
    end

    def search_tafsirs_text
      scope = Tafsir.includes(:verse)
      
      if filters[:chapter_id]
        scope = scope.where(chapter_id: filters[:chapter_id])
      end
      
      scope.where("text ILIKE ?", "%#{query}%").limit(30)
    end

    def script_field_name
      script = filters[:script] || :qpc_hafs
      "text_#{script}"
    end

    def parse_morphology_category
      # Simple keyword mapping for morphological categories
      case query.downcase
      when /noun|اسم/
        'noun'
      when /verb|فعل/
        'verb'
      when /particle|حرف/
        'particle'
      when /pronoun|ضمير/
        'pronoun'
      else
        query.downcase
      end
    end

    def might_be_morphology_query?
      morphology_keywords = %w[noun verb particle pronoun adjective اسم فعل حرف ضمير]
      morphology_keywords.any? { |keyword| query.downcase.include?(keyword) }
    end

    def expand_semantic_query(original_query)
      # Simple semantic expansion using synonyms
      synonyms_map = {
        'mercy' => ['forgiveness', 'compassion', 'grace', 'رحمة', 'مغفرة'],
        'prayer' => ['worship', 'salah', 'dua', 'صلاة', 'دعاء'],
        'guidance' => ['direction', 'path', 'way', 'هداية', 'طريق']
      }
      
      expanded_terms = [original_query]
      
      synonyms_map.each do |key, synonyms|
        if original_query.downcase.include?(key)
          expanded_terms.concat(synonyms)
        end
      end
      
      expanded_terms.join(' ')
    end

    def text_search_with_query(search_query)
      old_query = @query
      @query = search_query
      result = text_search
      @query = old_query
      result
    end

    def combine_and_deduplicate_verses(results_hash)
      all_verses = []
      verse_ids_seen = Set.new
      
      results_hash.values.flatten.each do |verse|
        next if verse_ids_seen.include?(verse.id)
        all_verses << verse
        verse_ids_seen << verse.id
      end
      
      all_verses.first(100) # Limit combined results
    end

    def format_results(results)
      {
        type: search_type,
        query: query,
        filters: filters,
        **results
      }
    end

    def format_verse_results(verses, options = {})
      {
        type: search_type,
        query: query,
        verses: verses.to_a,
        total_count: verses.size,
        highlight_options: options
      }
    end

    def format_morphology_results(morphology_words)
      verses = morphology_words.map(&:verse).uniq
      
      {
        type: :morphology,
        query: query,
        verses: verses,
        morphology_words: morphology_words.to_a,
        total_count: verses.size
      }
    end

    def empty_result
      {
        type: search_type,
        query: query,
        verses: [],
        total_count: 0,
        message: 'Empty query'
      }
    end

    def error_result(message)
      {
        type: search_type,
        query: query,
        verses: [],
        total_count: 0,
        error: message
      }
    end
  end
end