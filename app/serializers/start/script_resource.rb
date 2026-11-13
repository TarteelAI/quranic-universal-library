# frozen_string_literal: true

module Start
  # A script family of the guided setup (GuidedSetup::Script), with the most downloaded Quran
  # script of the family as its sample: the card preview of that script, while the `catalog`
  # group serves previews.
  class ScriptResource < ApplicationResource
    typelize key: :string, label: :string, blurb: :string
    attributes :key, :label, :blurb

    typelize sample: { nullable: true }
    one :sample, resource: Catalog::SearchResultResource, source: proc {
      next unless PageGroups.enabled?(:catalog)

      filters = Catalog::SearchFilters.from(type: 'quran-script', script: [key], sort: 'popular')
      Catalog::SearchQuery.new(filters, per_page: 1).call.results.first
    }
  end
end
