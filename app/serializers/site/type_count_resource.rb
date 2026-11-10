# frozen_string_literal: true

module Site
  # The number of published resources of one type (Catalog::Stats::TypeCount).
  class TypeCountResource < ApplicationResource
    typelize key: [:string, { enum: Catalog::Taxonomy.types.map(&:key) }], title: :string, count: :number
    attributes :key, :title, :count
  end
end
