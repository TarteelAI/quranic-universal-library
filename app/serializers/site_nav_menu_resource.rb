# frozen_string_literal: true

# One header menu (SiteNav::Menu): its overview page, its link groups and the side rail.
class SiteNavMenuResource < ApplicationResource
  typelize label: :string, href: :string, overview: :string, inertia: :boolean
  attributes :label, :href, :overview, :inertia
  many :groups, resource: SiteNavGroupResource
  many :aside, resource: SiteNavGroupResource
end
