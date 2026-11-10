# frozen_string_literal: true

module Catalog
  # One published resource as a catalog card (a DownloadableResource from Catalog::ResourcesQuery).
  class ResourceCardResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, to_param: :string, files_count: :number
    attributes :id, :name, :to_param, :files_count
    attribute(:type) { |resource| resource.resource_type }

    # The CMS row's language, else the content row's (a few translations only have the latter).
    typelize language: [:string, { nullable: true }]
    attribute :language do |resource|
      (resource.language || resource.resource_content&.language)&.name
    end

    typelize granularity: [:string, { nullable: true }]
    attribute(:granularity) { |resource| resource.humanize_cardinality_type }
  end
end
