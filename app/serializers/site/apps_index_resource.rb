# frozen_string_literal: true

module Site
  # Props of the apps directory (Site::AppsController#index): the apps that match the filters,
  # the number of apps in all, the filters applied and their options, and the resource types the
  # submission form offers.
  class AppsIndexResource < ApplicationResource
    typelize total: :number, catalog_pages: :boolean

    many :apps, source: proc { AppDirectory.filter(self[:apps], self[:filters]) }, resource: AppResource
    attribute(:total) { |page| page[:apps].size }
    one :filters, resource: AppFiltersResource

    many :platforms, source: proc { AppDirectory::PLATFORMS.values }, resource: Catalog::OptionResource
    # The resource types some app uses, in taxonomy order.
    many :types, source: proc {
      used = self[:apps].flat_map(&:uses).to_set
      Catalog::Taxonomy.types.select { |type| used.include?(type.key) }
    }, resource: Catalog::OptionResource

    many :submission_types, source: proc { Catalog::Taxonomy.types }, resource: Catalog::OptionResource
    attribute(:catalog_pages) { PageGroups.enabled?(:catalog) }
  end
end
