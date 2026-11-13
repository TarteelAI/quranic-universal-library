# frozen_string_literal: true

module Catalog
  # The input of Catalog::SearchQuery: a text query, one value for each filter except the script
  # family (any number of those), a sort (none groups the results by category) and a page. .from
  # builds it from a plain hash such as a query string; values outside the vocabularies are
  # dropped, never an error. `view` is how the catalog page lays the results out; search ignores it.
  class SearchFilters < Data.define(:q, :category, :type, :language, :script, :format, :granularity, :status, :sort,
                                    :page, :view,)
    MAX_QUERY_LENGTH = 200
    VIEWS = ['grid', 'list'].freeze

    def self.from(input)
      input = input.to_h.transform_keys(&:to_s)
      new(
        q: input['q'].is_a?(String) ? input['q'].strip.first(MAX_QUERY_LENGTH) : '',
        category: pick(input['category'], Taxonomy::CATEGORIES.values),
        type: pick(input['type'], Taxonomy.types),
        language: input['language'].is_a?(String) ? input['language'].strip.presence : nil,
        script: list(input['script']) & Taxonomy.script_families.map(&:key),
        format: pick(input['format'], Taxonomy.formats),
        granularity: pick(input['granularity'], Taxonomy.granularities),
        status: pick(input['status'], Taxonomy.statuses),
        sort: pick(input['sort'], Taxonomy.sorts),
        page: [input['page'].to_s[/\A\d+\z/].to_i, 1].max,
        view: VIEWS.include?(input['view']) ? input['view'] : VIEWS.first
      )
    end

    def self.pick(value, options)
      value if value.is_a?(String) && options.any? { |option| option.key == value }
    end

    # Several values: an array, the values of an indexed hash (`script[0]=…`) or a comma list.
    def self.list(value)
      values = case value
               when Array then value
               when Hash then value.values
               when String then value.split(',')
               else []
               end
      values.grep(String).map(&:strip).uniq
    end

    private_class_method :pick, :list
  end
end
