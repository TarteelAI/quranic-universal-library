# frozen_string_literal: true

module Catalog
  # The filters a catalog search applied (Catalog::SearchFilters), echoed so the page shows them.
  class SearchFiltersResource < ApplicationResource
    typelize q: :string,
             type: [:string, { nullable: true, enum: Taxonomy.types.map(&:key) }],
             language: [:string, { nullable: true }],
             script: [:string, { multi: true, enum: Taxonomy.script_families.map(&:key) }],
             format: [:string, { nullable: true, enum: Taxonomy.formats.map(&:key) }],
             granularity: [:string, { nullable: true, enum: Taxonomy.granularities.map(&:key) }],
             status: [:string, { nullable: true, enum: Taxonomy.statuses.map(&:key) }],
             sort: [:string, { enum: Taxonomy.sorts.map(&:key) }],
             page: :number
    attributes :q, :type, :language, :script, :format, :granularity, :status, :sort, :page
  end
end
