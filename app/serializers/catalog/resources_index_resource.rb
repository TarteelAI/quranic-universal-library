# frozen_string_literal: true

module Catalog
  # Props of the catalog page (Catalog::ResourcesController#index): one page of search results,
  # their category groups, the total, the facet counts and the filters applied. The vocabularies do not change between
  # searches, so the client receives them once.
  class ResourcesIndexResource < ApplicationResource
    typelize total: :number, page: :number, pages: :number
    attributes :total, :page, :pages

    one :filters, resource: SearchFiltersResource
    many :results, resource: SearchResultResource
    # The category headings over the results, when they are grouped (no sort and no query).
    typelize groups: { nullable: true }
    many :groups, resource: SearchGroupResource
    one :facets, resource: FacetsResource
    one :vocabularies, source: proc { slice(:languages) }, resource: VocabulariesResource, inertia: :once
  end
end
