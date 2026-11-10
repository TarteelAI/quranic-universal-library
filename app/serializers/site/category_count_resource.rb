# frozen_string_literal: true

module Site
  # The number of published resources of one category, and of each of its types
  # (Catalog::Stats::CategoryCount).
  class CategoryCountResource < ApplicationResource
    typelize key: [:string, { enum: Catalog::Taxonomy::CATEGORIES.keys }], label: :string, count: :number
    attributes :key, :label, :count

    many :types, resource: TypeCountResource
  end
end
