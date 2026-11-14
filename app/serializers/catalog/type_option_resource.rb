# frozen_string_literal: true

module Catalog
  # A resource type as a search filter value: its label and category, without the copy
  # Catalog::TypeResource carries, which the catalog's first response has no use for.
  class TypeOptionResource < ApplicationResource
    typelize key: :string, label: :string
    attributes :key, :label

    one :category, resource: CategoryResource
  end
end
