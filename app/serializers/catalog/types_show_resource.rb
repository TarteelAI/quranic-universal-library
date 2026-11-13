# frozen_string_literal: true

module Catalog
  # Props of a type page (Catalog::TypesController#show): the type, every type for the links
  # between type pages, a card per published resource of the type, the status and format labels,
  # the "Which one should I pick?" text, the type's guide and the comparison table.
  class TypesShowResource < ApplicationResource
    one :type, resource: TypeResource
    many :types, resource: TypeResource
    many :resources, resource: ResourceCardResource
    many :statuses, source: proc { Taxonomy.statuses }, resource: OptionResource
    many :formats, source: proc { Taxonomy.formats }, resource: OptionResource

    # Only where a resource of the type has a status other than the default, or is recommended.
    typelize pick: [:string, { nullable: true }]
    attribute :pick do |page|
      Taxonomy.pick(page[:type]) if page[:resources].any? { |resource| resource.recommended || !resource.stable? }
    end

    # The type's resource guide (the page the detail page's Data tab links to), when it has one.
    typelize guide_path: [:string, { nullable: true }]
    attribute(:guide_path) { |page| Taxonomy.guide_path(page[:type].key) }

    typelize comparison: { nullable: true }
    one :comparison, resource: ComparisonResource
  end
end
