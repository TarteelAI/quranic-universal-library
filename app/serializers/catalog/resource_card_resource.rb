# frozen_string_literal: true

module Catalog
  # One published resource as a catalog card (a DownloadableResource from Catalog::ResourcesQuery).
  class ResourceCardResource < ApplicationResource
    typelize id: :number, name: :string, type: :string, to_param: :string,
             status: [:string, { enum: Taxonomy.statuses.map(&:key) }]
    attributes :id, :to_param, :status
    attribute(:name, &:display_name)
    attribute(:type, &:resource_type)

    typelize summary: [:string, { nullable: true }]
    attribute(:summary) { |resource| resource.short_summary.presence }

    # The formats of the published files (the query preloads every file).
    typelize formats: [:string, { multi: true, enum: Taxonomy.formats.map(&:key) }]
    attribute :formats do |resource|
      Taxonomy.formats_of(resource.downloadable_files.select(&:published).map(&:file_type))
    end

    # The CMS row's language, else the content row's (a few translations only have the latter).
    typelize language: [:string, { nullable: true }]
    attribute :language do |resource|
      (resource.language || resource.resource_content&.language)&.name
    end

    typelize granularity: [:string, { nullable: true }]
    attribute(:granularity, &:humanize_cardinality_type)

    typelize script_family: [:string, { nullable: true }]
    attribute(:script_family) { |resource| Taxonomy.label(Taxonomy.script_families, resource.script_family) }

    # `drafted` while the flag is a backfill's suggestion no person has reviewed yet.
    typelize recommendation: [:string, { nullable: true, enum: ['reviewed', 'drafted'] }]
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
