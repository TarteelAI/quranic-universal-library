# frozen_string_literal: true

module Catalog
  # One published resource as a catalog card (a DownloadableResource from Catalog::ResourcesQuery).
  class ResourceCardResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, to_param: :string, files_count: :number,
             status: [:string, { enum: Taxonomy.statuses.map(&:key) }]
    attributes :id, :to_param, :files_count, :status
    attribute(:name, &:display_name)
    attribute(:type) { |resource| resource.resource_type }

    # The CMS row's language, else the content row's (a few translations only have the latter).
    typelize language: [:string, { nullable: true }]
    attribute :language do |resource|
      (resource.language || resource.resource_content&.language)&.name
    end

    typelize granularity: [:string, { nullable: true }]
    attribute(:granularity) { |resource| resource.humanize_cardinality_type }

    typelize script_family: [:string, { nullable: true }]
    attribute(:script_family) { |resource| Taxonomy.label(Taxonomy.script_families, resource.script_family) }

    # `drafted` while the flag is a backfill's suggestion no person has reviewed yet.
    typelize recommendation: [:string, { nullable: true, enum: %w[reviewed drafted] }]
    attribute :recommendation do |resource|
      (resource.reviewed?('recommended') ? 'reviewed' : 'drafted') if resource.recommended
    end

    # The kind of preview the card fetches once on screen (Previews::Card), or null for none.
    typelize preview_kind: [:string, { nullable: true, enum: Previews::Card::KINDS.values.uniq }]
    attribute(:preview_kind) { |resource| Previews::Card.kind(resource.resource_type) }

    typelize superseded_by: { nullable: true }
    one :superseded_by, source: proc { superseded_by if superseded_by&.published }, resource: ResourceRefResource
  end
end
