# frozen_string_literal: true

module Catalog
  # The facet counts of a catalog search (Catalog::SearchQuery::Result#facets), most results
  # first.
  class FacetsResource < ApplicationResource
    SearchQuery::FACETS.each do |facet|
      many facet, resource: FacetValueResource,
                  source: proc { fetch(facet).map { |value, count| { value: value, count: count } } }
    end
  end
end
