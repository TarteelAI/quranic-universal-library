# frozen_string_literal: true

module Site
  # The sample of a type on the home page's library cards (Catalog::Samples): the type, its
  # category, and the resource whose preview the category's card shows.
  class SampleResource < ApplicationResource
    typelize type: [:string, { enum: Catalog::Samples::TYPES.keys }],
             category: [:string, { enum: Catalog::Taxonomy::CATEGORIES.keys }],
             name: :string, to_param: :string
    attributes :type
    attribute(:category) { |sample| Catalog::Taxonomy.type(sample[:type]).category.key }
    attribute(:name) { |sample| sample[:resource].catalog_name }
    attribute(:to_param) { |sample| sample[:resource].to_param }
  end
end
