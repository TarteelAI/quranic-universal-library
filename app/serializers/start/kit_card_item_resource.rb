# frozen_string_literal: true

module Start
  # A resource on a starter kit's card: its name and the category that picks its icon.
  class KitCardItemResource < ApplicationResource
    typelize name: :string, category: [:string, { enum: Catalog::Taxonomy::CATEGORIES.keys }]
    attribute(:name, &:display_name)
    attribute(:category) { |resource| Catalog::Taxonomy.type(resource.resource_type).category.key }
  end
end
