# frozen_string_literal: true

# The header menus, the header search link and the footer links of the new pages (SiteNav).
class SiteNavResource < ApplicationResource
  many :menus, resource: SiteNavMenuResource
  one :search, resource: SiteNavLinkResource
  many :footer, resource: SiteNavGroupResource
end
