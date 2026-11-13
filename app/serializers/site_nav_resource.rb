# frozen_string_literal: true

# The home link, the header menus, the header search link, the footer links and the resource
# request form of the new pages (SiteNav), and whether the spotlight searches the docs.
class SiteNavResource < ApplicationResource
  one :home, resource: SiteNavLinkResource
  many :menus, resource: SiteNavMenuResource
  one :search, resource: SiteNavLinkResource
  many :footer, resource: SiteNavGroupResource
  one :request, resource: SiteNavLinkResource
  # The docs search index (/docs/search-index) exists while the docs pages are new pages.
  typelize docs_search: :boolean
  attribute(:docs_search) { PageGroups.enabled?(:content) }
end
