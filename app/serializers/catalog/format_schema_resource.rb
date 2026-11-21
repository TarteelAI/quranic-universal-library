# frozen_string_literal: true

module Catalog
  # A table or file a format doc describes (Catalog::FormatDoc::Schema): its columns or fields,
  # with the type where the doc names one.
  class FormatSchemaResource < ApplicationResource
    typelize name: [:string, { nullable: true }]
    attributes :name
    many :columns, resource: FormatColumnResource
  end
end
