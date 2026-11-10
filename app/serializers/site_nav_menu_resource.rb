# frozen_string_literal: true

# One header menu (SiteNav::Menu): its overview page, its link groups and the side rail.
# A `dense` menu lists many links in three columns and shows the side rail as a row of links.
class SiteNavMenuResource < ApplicationResource
  typelize label: :string, href: :string, overview: :string, inertia: :boolean, dense: :boolean
  attributes :label, :href, :overview, :inertia, :dense
  many :groups, resource: SiteNavGroupResource
  many :aside, resource: SiteNavGroupResource
end
