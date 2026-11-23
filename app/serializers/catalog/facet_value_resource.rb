# frozen_string_literal: true

module Catalog
  # One value of a search facet, with the number of results selecting it gives.
  class FacetValueResource < ApplicationResource
    typelize value: :string, count: :number
    attributes :value, :count
  end
end
