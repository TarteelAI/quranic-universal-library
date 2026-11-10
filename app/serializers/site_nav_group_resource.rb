# frozen_string_literal: true

# A titled list of links in a header menu or the footer (SiteNav::Group).
class SiteNavGroupResource < ApplicationResource
  typelize heading: :string, wide: :boolean
  attributes :heading, :wide
  many :links, resource: SiteNavLinkResource
end
