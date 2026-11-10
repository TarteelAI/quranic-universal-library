# frozen_string_literal: true

module Catalog
  # A link to another resource: enough to name it and build its detail path.
  class ResourceRefResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, to_param: :string
    attributes :id, :to_param
    attribute(:name, &:display_name)
    attribute(:type, &:resource_type)
  end
end
