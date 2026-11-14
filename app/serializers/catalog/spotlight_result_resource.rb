# frozen_string_literal: true

module Catalog
  # One spotlight result (a Catalog::SearchQuery::Row): enough to name it, show its type icon and
  # formats, and link to it. Download totals order the results and are not sent.
  class SpotlightResultResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, type_label: :string, to_param: :string,
             category: [:string, { enum: Taxonomy::CATEGORIES.keys }],
             language: [:string, { nullable: true }], formats: [:string, { multi: true }]
    attribute(:id) { |row| row.resource.id }
    attribute(:name) { |row| row.resource.display_name }
    attribute(:type) { |row| row.resource.resource_type }
    attribute(:type_label) { |row| Taxonomy.type(row.resource.resource_type).label }
    attribute(:category) { |row| Taxonomy.type(row.resource.resource_type).category.key }
    attribute(:to_param) { |row| row.resource.to_param }
    attribute(:language) { |row| row.language&.name }
    attribute(:formats) { |row| row.formats.map { |key| Taxonomy.label(Taxonomy.formats, key) } }
  end
end
