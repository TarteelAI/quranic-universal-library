# frozen_string_literal: true

module Content
  # /docs/search-index while the `content` page group is on: the docs search index
  # (Content::DocsSearchIndex) as JSON, which the docs layout and the spotlight fetch on first use
  # and match in the browser. Same-origin and internal: not part of the public API.
  class DocsSearchController < ApplicationController
    def index
      response.headers['X-Robots-Tag'] = 'noindex'
      render json: { pages: DocsSearchEntryResource.new(DocsSearchIndex.entries).serializable_hash }
    end
  end
end
