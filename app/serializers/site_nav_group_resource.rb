# frozen_string_literal: true

# A titled list of links in a header menu or the footer (SiteNav::Group). `tools` is true for a
# group of contribution tools only.
class SiteNavGroupResource < ApplicationResource
  typelize heading: :string, wide: :boolean, tools: :boolean
  attributes :heading, :wide, :tools
  many :links, resource: SiteNavLinkResource
end
