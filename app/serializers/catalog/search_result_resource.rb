# frozen_string_literal: true

module Catalog
  # One catalog search result (a Catalog::SearchQuery::Row). Download totals order the results
  # and are not sent.
  class SearchResultResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, to_param: :string,
             language: [:string, { nullable: true }], granularity: [:string, { nullable: true }],
             formats: [:string, { multi: true, enum: Taxonomy.formats.map(&:key) }],
             status: [:string, { enum: Taxonomy.statuses.map(&:key) }], recommended: :boolean
    attribute(:id) { |row| row.resource.id }
    attribute(:name) { |row| row.resource.display_name }
    attribute(:type) { |row| row.resource.resource_type }
    attribute(:to_param) { |row| row.resource.to_param }
    attribute(:language) { |row| row.language&.name }
    attribute(:granularity) { |row| row.resource.cardinality_type }
    attribute(:formats, &:formats)
    attribute(:status) { |row| row.resource.status }
    attribute(:recommended) { |row| row.resource.recommended }
  end
end
