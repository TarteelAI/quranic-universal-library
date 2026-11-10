# frozen_string_literal: true

module Catalog
  # /spotlight?q=…: the first few catalog search results as JSON, for the spotlight on every new
  # page. Without a query, the most popular resources in the catalog's popular order, which the
  # spotlight shows when it opens. Same-origin and internal: not versioned and not part of the
  # public API.
  class SpotlightController < ApplicationController
    LIMIT = 8
    POPULAR_LIMIT = 4

    def index
      filters = SearchFilters.from(q: params[:q], sort: 'popular')
      search = SearchQuery.new(filters, per_page: filters.q.empty? ? POPULAR_LIMIT : LIMIT).call

      response.headers['X-Robots-Tag'] = 'noindex'
      render json: { results: SpotlightResultResource.new(search.results).serializable_hash, total: search.total }
    end
  end
end
