# frozen_string_literal: true

module Catalog
  # One column or field of a format doc's schema (Catalog::FormatDoc::Column), as plain text.
  class FormatColumnResource < ApplicationResource
    typelize name: :string, type: [:string, { nullable: true }], description: [:string, { nullable: true }]
    attributes :name, :type, :description
  end
end
