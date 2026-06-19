module Utils
  class QuranSearch
    def initialize
      @elasticsearch_enabled = defined?(Searchkick) && Searchkick.client.present?
    end

    def search(query, options = {})
      return fallback_search(query) unless @elasticsearch_enabled

      begin
        elasticsearch_search(query, options)
      rescue => e
        Rails.logger.error "Elasticsearch search failed: #{e.message}"
        fallback_search(query)
      end
    end

    private

    def elasticsearch_search(query, options = {})
      # Multi-model search across verses and their translations
      verses = Verse.elasticsearch_search(query, 
        page: options[:page] || 1,
        per_page: options[:per_page] || 20,
        filters: options[:filters] || {}
      )

      # Format results in the same structure as the original API
      {
        'verses' => format_verses_for_compatibility(verses),
        'navigation' => [],
        'total_results' => verses.total_count,
        'search_time' => verses.try(:took) || 0,
        'suggestions' => extract_search_suggestions(verses)
      }
    end

    def fallback_search(query)
      # Fallback to database search if Elasticsearch is not available
      verses = Verse.joins(:translations)
                   .where("verses.text_uthmani ILIKE ? OR translations.text ILIKE ?", 
                          "%#{query}%", "%#{query}%")
                   .includes(:translations, :words)
                   .limit(20)
                   .distinct

      {
        'verses' => format_verses_for_compatibility(verses),
        'navigation' => [],
        'total_results' => verses.count,
        'search_time' => 0,
        'suggestions' => []
      }
    rescue => e
      Rails.logger.error "Fallback search failed: #{e.message}"
      {
        'verses' => [],
        'navigation' => [],
        'error' => e.message
      }
    end

    def format_verses_for_compatibility(verses)
      verses.map do |verse|
        {
          'verse_key' => verse.verse_key,
          'chapter_id' => verse.chapter_id,
          'verse_number' => verse.verse_number,
          'text_uthmani' => verse.text_uthmani,
          'words' => format_words_with_highlights(verse, verses.try(:highlights) || {})
        }
      end
    end

    def format_words_with_highlights(verse, highlights)
      # Split verse text into words and check for highlights
      words = verse.text_uthmani.split(' ')
      highlight_text = highlights.dig(verse.id.to_s, 'text_uthmani')&.first || verse.text_uthmani

      words.map.with_index do |word, index|
        {
          'text' => word,
          'highlight' => highlight_text.include?(word)
        }
      end
    end

    def extract_search_suggestions(results)
      return [] unless results.respond_to?(:suggestions)

      results.suggestions.map do |suggestion|
        {
          'text' => suggestion['text'],
          'score' => suggestion['score'] || 1.0
        }
      end
    end
  end
end