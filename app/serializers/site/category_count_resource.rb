# frozen_string_literal: true

module Site
  # The number of published resources of one category, with its one-line hint
  # (Catalog::Stats::CategoryCount).
  class CategoryCountResource < ApplicationResource
    typelize key: [:string, { enum: Catalog::Taxonomy::CATEGORIES.keys }], label: :string, hint: :string,
             count: :number
    attributes :key, :label, :hint, :count
  end
end
