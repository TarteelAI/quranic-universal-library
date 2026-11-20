# frozen_string_literal: true

module Catalog
  # The header of a resource detail page: names, catalog fields (labels for script family and
  # granularity, the status key), the summary and the editor's description as sanitized HTML.
  class ResourceDetailResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, to_param: :string,
             status: [:string, { enum: Taxonomy.statuses.map(&:key) }],
             script_family: [:string, { nullable: true }], language: [:string, { nullable: true }],
             granularity: [:string, { nullable: true }], summary: [:string, { nullable: true }],
             info: [:string, { nullable: true }], recommended: :boolean
    attributes :id, :to_param, :status, :recommended
    attribute(:name, &:display_name)
    attribute(:type, &:resource_type)
    attribute(:script_family) { |resource| Taxonomy.label(Taxonomy.script_families, resource.script_family) }
    attribute(:language) { |resource| (resource.language || resource.resource_content&.language)&.name }
    attribute(:granularity, &:humanize_cardinality_type)
    attribute(:summary, &:summary)
    attribute(:info) { |resource| ResourcePage.sanitize(resource.info) }

    typelize superseded_by: { nullable: true }
    one :superseded_by, source: proc { superseded_by if superseded_by&.published }, resource: ResourceRefResource
  end
end
