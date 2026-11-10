# frozen_string_literal: true

module Catalog
  # A resource in a "Works with" group. `reviewed` is false while the link is a backfill's draft.
  class WorksWithLinkResource < ApplicationResource
    typelize reviewed: :boolean, type_label: :string
    attributes :reviewed
    attribute(:type_label) { |link| Taxonomy.type(link.resource.resource_type)&.label || link.resource.resource_type }

    one :resource, resource: ResourceRefResource
  end
end
