# frozen_string_literal: true

module Catalog
  # A column of a type page's comparison table (Catalog::Taxonomy::COMPARISON_COLUMNS).
  class ComparisonColumnResource < ApplicationResource
    typelize key: [:string, { enum: Taxonomy::COMPARISON_COLUMNS.keys }], label: :string
    attributes :key, :label
  end
end
