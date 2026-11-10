# frozen_string_literal: true

module Catalog
  # The labels of every search filter value and sort. The object holds the catalog's
  # languages; the other vocabularies come from Catalog::Taxonomy.
  class VocabulariesResource < ApplicationResource
    many :types, source: proc { Taxonomy.types }, resource: TypeResource
    many :languages, resource: LanguageResource
    many :script_families, source: proc { Taxonomy.script_families }, resource: OptionResource
    many :formats, source: proc { Taxonomy.formats }, resource: OptionResource
    many :granularities, source: proc { Taxonomy.granularities }, resource: OptionResource
    many :statuses, source: proc { Taxonomy.statuses }, resource: OptionResource
    many :sorts, source: proc { Taxonomy.sorts }, resource: OptionResource
  end
end
