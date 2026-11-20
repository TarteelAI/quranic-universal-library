# frozen_string_literal: true

# The home link, the header menus, the header search link, the footer links and the resource
# request form of the new pages (SiteNav), whether the spotlight searches the docs and whether
# the header has the bundle tray.
class SiteNavResource < ApplicationResource
  one :home, resource: SiteNavLinkResource
  many :menus, resource: SiteNavMenuResource
  one :search, resource: SiteNavLinkResource
  many :footer, resource: SiteNavGroupResource
  one :request, resource: SiteNavLinkResource
  # The docs search index (/docs/search-index) exists while the docs pages are new pages.
  typelize docs_search: :boolean
  attribute(:docs_search) { PageGroups.enabled?(:content) }
  # The bundle tray and its add buttons, while the catalog pages (and the tray's lookup) are new.
  typelize bundle: :boolean
  attribute(:bundle) { PageGroups.enabled?(:catalog) }
end
