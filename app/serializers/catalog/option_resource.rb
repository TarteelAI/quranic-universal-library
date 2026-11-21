# frozen_string_literal: true

module Catalog
  # A value of a search vocabulary with its label (Catalog::Taxonomy::Option).
  class OptionResource < ApplicationResource
    typelize key: :string, label: :string
    attributes :key, :label
  end
end
