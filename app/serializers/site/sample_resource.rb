# frozen_string_literal: true

module Site
  # A tab of the home page's data showcase (Catalog::Samples): the type, its category and number
  # of published resources, and the resource whose preview the tab shows.
  class SampleResource < ApplicationResource
    typelize type: [:string, { enum: Catalog::Samples::TYPES.keys }],
             category: [:string, { enum: Catalog::Taxonomy::CATEGORIES.keys }], count: :number,
             name: :string, to_param: :string
    attributes :type, :count
    attribute(:category) { |sample| Catalog::Taxonomy.type(sample[:type]).category.key }
    attribute(:name) { |sample| sample[:resource].display_name }
    attribute(:to_param) { |sample| sample[:resource].to_param }
  end
end
