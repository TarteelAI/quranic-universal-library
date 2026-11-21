# frozen_string_literal: true

module Catalog
  # A language of the catalog. `key` is the ISO code the language filter takes.
  class LanguageResource < ApplicationResource
    typelize key: :string, name: :string, native_name: [:string, { nullable: true }]
    attribute(:key, &:iso_code)
    attributes :name
    attribute(:native_name) { |language| language.native_name.presence }
  end
end
