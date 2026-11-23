# frozen_string_literal: true

module Catalog
  # A typed link from a resource to another one (a Catalog::Derived::Link).
  class RelationResource < ApplicationResource
    typelize relation_type: [:string, { enum: Derived::RELATION_TYPES }]
    attributes :relation_type

    one :resource, source: proc { target }, resource: ResourceRefResource
  end
end
