# frozen_string_literal: true

# The header menus, the header search link, the footer links and the resource request form of the
# new pages (SiteNav).
class SiteNavResource < ApplicationResource
  many :menus, resource: SiteNavMenuResource
  one :search, resource: SiteNavLinkResource
  many :footer, resource: SiteNavGroupResource
  one :request, resource: SiteNavLinkResource
end
