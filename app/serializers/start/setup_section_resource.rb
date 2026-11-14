# frozen_string_literal: true

module Start
  # One item of the needs checklist on the guided setup's results (a
  # Start::SetupController::Section): its label, its catalog search (the first cards and
  # the total) and the catalog URL that lists all of them.
  class SetupSectionResource < ApplicationResource
    typelize key: :string, label: :string, type: :string, total: :number, catalog_path: :string
    attribute(:key) { |section| [section.item.need.key, section.item.language].compact.join('-') }
    attributes :label
    attribute(:type) { |section| section.item.filters.fetch('type') }
    attribute(:total) { |section| section.search.total }
    attribute :catalog_path do |section|
      Rails.application.routes.url_helpers.catalog_resources_path(section.item.filters)
    end
    many :results, source: proc { search.results }, resource: Catalog::SearchResultResource
  end
end
