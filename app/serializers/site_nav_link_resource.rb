# frozen_string_literal: true

# A link in the site navigation (SiteNav::Link). `inertia` links go to a new page; the others
# load an old page or another site in full.
class SiteNavLinkResource < ApplicationResource
  typelize label: :string, href: :string, description: [:string, { nullable: true }],
           category: [:string, { nullable: true, enum: Catalog::Taxonomy::CATEGORIES.keys }],
           icon: [:string, { nullable: true, enum: SiteNav::ICONS }], external: :boolean, inertia: :boolean
  attributes :label, :href, :description, :category, :icon, :external, :inertia
end
