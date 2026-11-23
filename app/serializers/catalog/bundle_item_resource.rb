# frozen_string_literal: true

module Catalog
  # One resource of the bundle tray (a Catalog::Bundle::Item): the id the browser holds, the
  # resource and its files, or no resource when the id is no longer a published resource.
  # `restricted` is a resource the viewer may not download, sent with no files.
  class BundleItemResource < ApplicationResource
    typelize id: :number, restricted: :boolean
    attributes :id, :restricted

    typelize resource: { nullable: true }
    one :resource, resource: ResourceRefResource

    typelize category: [:string, { nullable: true, enum: Taxonomy::CATEGORIES.keys }]
    attribute(:category) { |item| item.resource && Taxonomy.type(item.resource.resource_type).category.key }

    many :files, resource: ResourceFileResource
  end
end
