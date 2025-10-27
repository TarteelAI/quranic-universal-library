# frozen_string_literal: true

module Searchable
  extend ActiveSupport::Concern

  included do
    include Searchkick if defined?(Searchkick)
  end

  module ClassMethods
    # Common search functionality for Quran models
    def elasticsearch_search(query, options = {})
      return none unless defined?(Searchkick)
      
      search_options = {
        fields: search_fields,
        highlight: { fields: highlight_fields },
        suggest: [:text],
        misspellings: { below: 5 },
        page: options[:page] || 1,
        per_page: options[:per_page] || 20,
        boost_by: boost_fields,
        where: build_search_filters(options[:filters] || {})
      }.merge(options[:search_options] || {})

      search(query, search_options)
    end

    # Semantic search using vector similarity (if embeddings are available)
    def semantic_search(query, options = {})
      return elasticsearch_search(query, options) unless respond_to?(:embedding_field)
      
      # This would integrate with sentence transformers or similar
      # For now, fall back to regular search with semantic boost
      semantic_options = options.merge(
        search_options: {
          boost_by: semantic_boost_fields,
          fields: semantic_search_fields
        }
      )
      
      elasticsearch_search(query, semantic_options)
    end

    # Morphology-based search
    def morphology_search(filters = {})
      return none unless respond_to?(:morphology_search_fields)
      
      where_filters = {}
      
      filters.each do |key, value|
        case key.to_s
        when 'part_of_speech'
          where_filters[:part_of_speech_key] = value
        when 'root'
          where_filters[:root_name] = value
        when 'lemma'  
          where_filters[:lemma_name] = value
        when 'pos_tags'
          where_filters[:pos_tags] = value
        end
      end

      search('*', where: where_filters, limit: 1000)
    end

    private

    def build_search_filters(filters)
      where_filters = {}
      
      filters.each do |key, value|
        next if value.blank?
        
        case key.to_s
        when 'chapter_id'
          where_filters[:chapter_id] = value
        when 'verse_key'
          where_filters[:verse_key] = value
        when 'language_id'
          where_filters[:language_id] = value
        when 'juz_number'
          where_filters[:juz_number] = value
        when 'hizb_number'
          where_filters[:hizb_number] = value
        end
      end
      
      where_filters
    end
  end

  # Instance methods
  def search_data
    # Default implementation - override in models
    as_json(only: searchable_attributes)
  end

  private

  def searchable_attributes
    self.class.column_names - %w[created_at updated_at]
  end
end