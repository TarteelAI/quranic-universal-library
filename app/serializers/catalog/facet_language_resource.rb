# frozen_string_literal: true

module Catalog
  # A language filter value: the ISO code, the name and the number of results selecting it gives.
  class FacetLanguageResource < ApplicationResource
    typelize key: :string, name: :string, count: :number
    attributes :key, :name, :count
  end
end
