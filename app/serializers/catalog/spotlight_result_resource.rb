# frozen_string_literal: true

module Catalog
  # One spotlight result (a Catalog::SearchQuery::Row): enough to name it and link to it.
  class SpotlightResultResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, type_label: :string, to_param: :string,
             language: [:string, { nullable: true }]
    attribute(:id) { |row| row.resource.id }
    attribute(:name) { |row| row.resource.display_name }
    attribute(:type) { |row| row.resource.resource_type }
    attribute(:type_label) { |row| Taxonomy.type(row.resource.resource_type).label }
    attribute(:to_param) { |row| row.resource.to_param }
    attribute(:language) { |row| row.language&.name }
  end
end
