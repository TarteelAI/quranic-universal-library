# frozen_string_literal: true

module Catalog
  # One resource with its catalog fields (Catalog::Derived): lifecycle status and replacement,
  # the recommended flag, script family, rendering, summary and typed relations. Relations and
  # the replacement point at published resources only, requires-links first.
  class ResourceResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, to_param: :string, recommended: :boolean,
             status: [:string, { enum: Derived::STATUSES }],
             script_family: [:string, { nullable: true, enum: Derived::SCRIPT_FAMILIES }],
             rendering: [:string, { nullable: true, enum: Derived::RENDERINGS }],
             summary: [:string, { nullable: true }]
    attributes :id, :to_param, :status, :recommended, :script_family, :rendering
    attribute(:name, &:display_name)
    attribute(:type, &:resource_type)
    attribute(:summary, &:summary)

    typelize superseded_by: { nullable: true }
    one :superseded_by, source: proc { superseded_by if superseded_by&.published }, resource: ResourceRefResource

    many :relations, resource: RelationResource, source: proc {
      Derived.current.links_from(self).select { |link| link.target.published }
        .sort_by.with_index { |link, index| [link.requires? ? 0 : 1, index] }
    }
  end
end
