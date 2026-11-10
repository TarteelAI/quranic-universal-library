# frozen_string_literal: true

module Catalog
  # Props of a type page (Catalog::TypesController#show): the type, every type for the links
  # between type pages, and a card per published resource of the type.
  class TypesShowResource < ApplicationResource
    one :type, resource: TypeResource
    many :types, resource: TypeResource
    many :resources, resource: ResourceCardResource
  end
end
