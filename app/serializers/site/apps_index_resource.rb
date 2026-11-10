# frozen_string_literal: true

module Site
  # Props of the apps directory (Site::AppsController#index): the apps that match the filters,
  # the number of apps in all, the filters applied and their options, and the submission form.
  class AppsIndexResource < ApplicationResource
    typelize total: :number, catalog_pages: :boolean, submit_url: :string

    many :apps, source: proc { AppDirectory.filter(self[:apps], self[:filters]) }, resource: AppResource
    attribute(:total) { |page| page[:apps].size }
    one :filters, resource: AppFiltersResource

    many :platforms, source: proc { AppDirectory::PLATFORMS.values }, resource: Catalog::OptionResource
    # The resource types some app uses, in taxonomy order.
    many :types, source: proc {
      used = self[:apps].flat_map(&:uses).to_set
      Catalog::Taxonomy.types.select { |type| used.include?(type.key) }
    }, resource: Catalog::OptionResource

    attribute(:submit_url) { AppDirectory::SUBMIT_URL }
    attribute(:catalog_pages) { PageGroups.enabled?(:catalog) }
  end
end
