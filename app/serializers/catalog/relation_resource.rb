# frozen_string_literal: true

module Catalog
  # A typed link from a resource to another one (a DownloadableRelatedResource). `reviewed` is
  # false while the link is a backfill's draft.
  class RelationResource < ApplicationResource
    typelize relation_type: [:string, { enum: DownloadableRelatedResource.relation_types.keys }], reviewed: :boolean
    attributes :relation_type
    attribute(:reviewed) { |link| link.downloadable_resource.reviewed?("link:#{link.related_resource_id}") }

    one :resource, source: proc { related_resource }, resource: ResourceRefResource
  end
end
