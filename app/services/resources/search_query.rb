# frozen_string_literal: true

module Resources
  class SearchQuery
    TagFacet = Struct.new(:tag, :name, :count, :selected, keyword_init: true)
    TypeFacet = Struct.new(:resource_type, :name, :count, :selected, keyword_init: true)

    Result = Struct.new(
      :query,
      :text_query,
      :selected_tags,
      :selected_resource_types,
      :parsed_reference,
      :results,
      :primary_results,
      :related_results,
      :available_tags,
      :available_resource_types,
      :global,
      keyword_init: true
    ) do
      def active?
        query.present? || selected_tags.any? || selected_resource_types.any?
      end

      def quran_reference?
        parsed_reference.present?
      end

      def normalized_ayah
        parsed_reference&.verse_key
      end

      def result_count
        results.count
      end
    end

    CARDINALITY_PRIORITY = {
      ResourceContent::CardinalityType::OneVerse => 90,
      ResourceContent::CardinalityType::OneWord => 84,
      ResourceContent::CardinalityType::OnePhrase => 78,
      ResourceContent::CardinalityType::NVerse => 72,
      ResourceContent::CardinalityType::OneChapter => 42,
      ResourceContent::CardinalityType::OnePage => 38,
      ResourceContent::CardinalityType::Quran => 26,
      ResourceContent::CardinalityType::OneJuz => 18,
      ResourceContent::CardinalityType::OneHizb => 18,
      ResourceContent::CardinalityType::OneRub => 18,
      ResourceContent::CardinalityType::OneRuku => 18,
      ResourceContent::CardinalityType::OneManzil => 18
    }.freeze

    TYPE_PRIORITY = {
      'recitation' => 28,
      'quran-script' => 27,
      'translation' => 26,
      'tafsir' => 25,
      'transliteration' => 24,
      'morphology' => 23,
      'mutashabihat' => 22,
      'similar-ayah' => 21,
      'ayah-theme' => 20,
      'ayah-topics' => 19,
      'quran-metadata' => 18,
      'surah-info' => 12,
      'mushaf-layout' => 11,
      'font' => 10
    }.freeze

    def initialize(scope:, query:, selected_tags:, selected_resource_types: [], global:)
      @scope = scope
      @query = query.to_s.strip
      @selected_tags = Array(selected_tags).map(&:to_s).map(&:strip).reject(&:blank?)
      @selected_resource_types = Array(selected_resource_types).map(&:to_s).map(&:strip).reject(&:blank?)
      @global = global
    end

    def call
      text_query = normalize_text(query)

      candidate_resources = filter_by_text(resources, text_query)
      candidate_resources = filter_by_tags(candidate_resources)
      available_resource_types = build_type_facets(candidate_resources)
      candidate_resources = filter_by_resource_types(candidate_resources)
      sorted_resources = sort_resources(candidate_resources, text_query)
      available_tags = build_tag_facets(sorted_resources)

      Result.new(
        query: query,
        text_query: text_query,
        selected_tags: selected_tags,
        selected_resource_types: selected_resource_types,
        parsed_reference: nil,
        results: sorted_resources,
        primary_results: sorted_resources,
        related_results: [],
        available_tags: available_tags,
        available_resource_types: available_resource_types,
        global: global
      )
    end

    private

    attr_reader :scope, :query, :selected_tags, :selected_resource_types, :global

    def resources
      @resources ||= scope.to_a
    end

    def filter_by_text(resources, text_query)
      return resources if text_query.blank?

      terms = text_query.split

      resources.select do |resource|
        searchable_blob(resource).then do |blob|
          terms.all? { |term| blob.include?(term) }
        end
      end
    end

    def filter_by_tags(resources)
      return resources if selected_tags.empty?

      resources.select do |resource|
        normalized_tag_names = resource.downloadable_resource_tags.map { |tag| normalize_text(tag.name) }
        selected_tags.all? { |tag_name| normalized_tag_names.include?(normalize_text(tag_name)) }
      end
    end

    def filter_by_resource_types(resources)
      return resources if selected_resource_types.empty?

      allowed_types = selected_resource_types.map { |type| normalize_text(type) }

      resources.select do |resource|
        allowed_types.include?(normalize_text(resource.resource_type))
      end
    end

    def sort_resources(resources, text_query)
      return resources if text_query.blank?

      resources.sort_by do |resource|
        [
          -score_resource(resource, text_query),
          resource.name.to_s.downcase,
          resource.id.to_i
        ]
      end
    end

    def score_resource(resource, text_query)
      text_terms = text_query.split
      score = text_score(resource, text_terms)
      score += TYPE_PRIORITY.fetch(resource.resource_type, 0)
      score + CARDINALITY_PRIORITY.fetch(resource.cardinality_type, 0)
    end

    def text_score(resource, text_terms)
      return 0 if text_terms.empty?

      fields = {
        name: normalize_text(resource.name),
        tags: normalize_text(resource.downloadable_resource_tags.map(&:name).join(' '))
      }

      score = 0
      text_terms.each do |term|
        score += 30 if fields[:name].split.include?(term)
        score += 18 if fields[:name].include?(term)
        score += 14 if fields[:tags].split.include?(term)
        score += 8 if fields[:tags].include?(term)
      end

      score
    end

    def build_tag_facets(resources)
      facets = {}

      resources.each do |resource|
        resource.downloadable_resource_tags.each do |tag|
          key = normalize_text(tag.name)
          next if key.blank?

          entry = (facets[key] ||= { tag: tag, count: 0 })
          entry[:count] += 1
        end
      end

      facets.values
            .map do |facet|
              TagFacet.new(
                tag: facet[:tag],
                name: facet[:tag].name,
                count: facet[:count],
                selected: selected_tags.any? { |tag_name| normalize_text(tag_name) == normalize_text(facet[:tag].name) }
              )
            end
            .sort_by { |facet| [-facet.count, facet.name.downcase] }
    end

    def build_type_facets(resources)
      facets = resources.each_with_object(Hash.new(0)) do |resource, counts|
        counts[resource.resource_type.to_s] += 1
      end

      facets.map do |resource_type, count|
        TypeFacet.new(
          resource_type: resource_type,
          name: humanize_resource_type(resource_type),
          count: count,
          selected: selected_resource_types.any? { |selected_type| normalize_text(selected_type) == normalize_text(resource_type) }
        )
      end.sort_by { |facet| [-facet.count, facet.name.downcase] }
    end

    def searchable_blob(resource)
      @searchable_blob ||= {}
      @searchable_blob[resource.id] ||= normalize_text(
        [
          resource.name,
          resource.downloadable_resource_tags.map(&:name).join(' ')
        ].compact.join(' ')
      )
    end

    def normalize_text(text)
      ActiveSupport::Inflector
        .transliterate(text.to_s)
        .downcase
        .tr('-', ' ')
        .gsub(/[^a-z0-9:\s]/, ' ')
        .squeeze(' ')
        .strip
    end

    def humanize_resource_type(resource_type)
      resource_type.to_s.tr('-', ' ').split.map(&:capitalize).join(' ')
    end
  end
end
