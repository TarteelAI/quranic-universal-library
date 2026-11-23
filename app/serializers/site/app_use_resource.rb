# frozen_string_literal: true

module Site
  # A resource type an app uses (Catalog::Taxonomy::Type), with its category for the chip's tint.
  class AppUseResource < ApplicationResource
    typelize key: [:string, { enum: Catalog::Taxonomy.types.map(&:key) }], label: :string,
             category: [:string, { enum: Catalog::Taxonomy::CATEGORIES.keys }]
    attributes :key, :label

    attribute :category do |type|
      type.category.key
    end
  end
end
