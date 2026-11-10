# frozen_string_literal: true

module Site
  # Props of the home page (Site::HomeController#show): the catalog counts, the categories with
  # their types, the apps of the showcase and the links that depend on the page groups.
  class HomeShowResource < ApplicationResource
    typelize resources: :number, languages: :number, recitations: :number, apps_count: :number,
             catalog_pages: :boolean, apps_page: :boolean, submit_url: :string

    attribute(:resources) { |page| page[:stats].resources }
    attribute(:languages) { |page| page[:stats].languages }
    attribute(:recitations) { |page| page[:stats].recitations }
    many :categories, source: proc { self[:stats].categories }, resource: CategoryCountResource

    many :showcase, resource: AppResource
    attribute(:apps_count) { |page| page[:apps].size }
    attribute(:submit_url) { AppDirectory::SUBMIT_URL }
    # Whether the catalog and the apps directory are new pages (Inertia visits) or, for the
    # catalog, old pages; with the `apps` group off there is no apps directory.
    attribute(:catalog_pages) { PageGroups.enabled?(:catalog) }
    attribute(:apps_page) { PageGroups.enabled?(:apps) }
  end
end
