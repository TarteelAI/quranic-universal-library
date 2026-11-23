# frozen_string_literal: true

module Catalog
  # The comparison table of a type page (Catalog::Comparison::Table).
  class ComparisonResource < ApplicationResource
    many :columns, resource: ComparisonColumnResource
    many :rows, resource: ComparisonRowResource
  end
end
