# frozen_string_literal: true

module Catalog
  # The header of a resource detail page: names, catalog fields (labels for script family and
  # granularity, the status key), the summary and the editor's description as sanitized HTML.
  class ResourceDetailResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, to_param: :string,
             status: [:string, { enum: Taxonomy.statuses.map(&:key) }],
             script_family: [:string, { nullable: true }], language: [:string, { nullable: true }],
             granularity: [:string, { nullable: true }], summary: [:string, { nullable: true }],
             info: [:string, { nullable: true }],
             recommendation: [:string, { nullable: true, enum: %w[reviewed drafted] }]
    attributes :id, :to_param, :status
    attribute(:name, &:display_name)
    attribute(:type, &:resource_type)
    attribute(:script_family) { |resource| Taxonomy.label(Taxonomy.script_families, resource.script_family) }
    attribute(:language) { |resource| (resource.language || resource.resource_content&.language)&.name }
    attribute(:granularity, &:humanize_cardinality_type)
    attribute(:summary) { |resource| resource.short_summary.presence }
    attribute(:info) { |resource| ResourcePage.sanitize(resource.info) }
    # `drafted` while the flag is a backfill's suggestion no person has reviewed yet.
    attribute :recommendation do |resource|
      (resource.reviewed?('recommended') ? 'reviewed' : 'drafted') if resource.recommended
    end

    one :reviewed, source: proc { self }, resource: ResourceReviewResource

    typelize superseded_by: { nullable: true }
    one :superseded_by, source: proc { superseded_by if superseded_by&.published }, resource: ResourceRefResource
  end
end
