# frozen_string_literal: true

module Catalog
  # /spotlight?q=…: the first few catalog search results as JSON, for the spotlight on every new
  # page. Same-origin and internal: not versioned and not part of the public API.
  class SpotlightController < ApplicationController
    LIMIT = 8

    def index
      search = SearchQuery.new(SearchFilters.from(q: params[:q]), per_page: LIMIT).call

      response.headers['X-Robots-Tag'] = 'noindex'
      render json: { results: SpotlightResultResource.new(search.results).serializable_hash, total: search.total }
    end
  end
end
