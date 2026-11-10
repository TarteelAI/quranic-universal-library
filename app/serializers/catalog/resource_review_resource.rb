# frozen_string_literal: true

module Catalog
  # Per drafted field of a resource: true when a person set or reviewed the value, false while
  # it is a backfill's draft (shown as "not yet reviewed").
  class ResourceReviewResource < ApplicationResource
    FIELDS = {
      status: 'status', superseded_by: 'superseded_by_id', recommended: 'recommended',
      script_family: 'script_family', rendering: 'rendering', summary: 'short_summary'
    }.freeze

    FIELDS.each do |key, field|
      typelize key => :boolean
      attribute(key) { |resource| resource.reviewed?(field) }
    end
  end
end
