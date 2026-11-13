# frozen_string_literal: true

module Catalog
  # The search state of a type page with many resources (Catalog::TypesController): the query,
  # the language and the page applied, the page count, the number of matches, and the languages
  # of the type's resources with how many match the query in each.
  class TypeSearchResource < ApplicationResource
    typelize q: :string, language: [:string, { nullable: true }], page: :number, pages: :number, matches: :number
    attributes :q, :language, :page, :pages, :matches

    many :languages, resource: FacetLanguageResource
  end
end
