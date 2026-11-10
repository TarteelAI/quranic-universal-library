# frozen_string_literal: true

module Catalog
  # One resource with its catalog fields: lifecycle status and replacement, the recommended
  # flag, script family, rendering, summary and typed relations, and per drafted field whether
  # a person has reviewed it. Relations and the replacement point at published resources only,
  # requires-links first. Callers that serialize many resources preload
  # `downloadable_related_resources: :related_resource` and `:superseded_by`.
  class ResourceResource < ApplicationResource
    RELATION_ORDER = DownloadableRelatedResource.relation_types.keys

    typelize id: :number, name: :string, type: :string, to_param: :string, recommended: :boolean,
             status: [:string, { enum: DownloadableResource.statuses.keys }],
             script_family: [:string, { nullable: true, enum: DownloadableResource.script_families.keys }],
             rendering: [:string, { nullable: true, enum: DownloadableResource.renderings.keys }],
             summary: [:string, { nullable: true }]
    attributes :id, :to_param, :status, :recommended, :script_family, :rendering
    attribute(:name, &:display_name)
    attribute(:type, &:resource_type)
    attribute(:summary) { |resource| resource.short_summary.presence }

    typelize superseded_by: { nullable: true }
    one :superseded_by, source: proc { superseded_by if superseded_by&.published }, resource: ResourceRefResource

    one :reviewed, source: proc { self }, resource: ResourceReviewResource

    many :relations, resource: RelationResource, source: proc {
      downloadable_related_resources.select { |link| link.related_resource&.published }
                                    .sort_by { |link| [RELATION_ORDER.index(link.relation_type), link.id] }
    }
  end
end
