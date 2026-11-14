# frozen_string_literal: true

module Catalog
  # A catalog category (Catalog::Taxonomy::Category).
  class CategoryResource < ApplicationResource
    typelize key: [:string, { enum: Taxonomy::CATEGORIES.keys }], label: :string
    attributes :key, :label
  end
end
