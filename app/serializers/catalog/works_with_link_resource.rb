# frozen_string_literal: true

module Catalog
  # A resource in a "Works with" group.
  class WorksWithLinkResource < ApplicationResource
    typelize type_label: :string
    attribute(:type_label) { |link| Taxonomy.type(link.resource.resource_type)&.label || link.resource.resource_type }

    one :resource, resource: ResourceRefResource
  end
end
