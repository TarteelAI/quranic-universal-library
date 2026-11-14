# frozen_string_literal: true

module Catalog
  # One resource in a type page's comparison table (Catalog::Comparison::Row). Script family and
  # rendering are labels; pages and lines per page are set for layouts only.
  class ComparisonRowResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, to_param: :string,
             status: [:string, { enum: Taxonomy.statuses.map(&:key) }],
             script_family: [:string, { nullable: true }], rendering: [:string, { nullable: true }],
             pages: [:number, { nullable: true }], lines_per_page: [:number, { nullable: true }]
    attributes :pages, :lines_per_page
    attribute(:id) { |row| row.resource.id }
    attribute(:name) { |row| row.resource.display_name }
    attribute(:type) { |row| row.resource.resource_type }
    attribute(:to_param) { |row| row.resource.to_param }
    attribute(:status) { |row| row.resource.status }
    attribute(:script_family) { |row| Taxonomy.label(Taxonomy.script_families, row.resource.script_family) }
    attribute(:rendering) { |row| Taxonomy.label(Taxonomy.renderings, row.resource.rendering) }

    typelize font: { nullable: true }
    one :font, resource: ResourceRefResource
  end
end
