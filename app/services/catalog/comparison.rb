# frozen_string_literal: true

module Catalog
  # The comparison table of a type page: the type's columns (Taxonomy::COMPARISONS) and one row
  # per published resource. Nil for a type without a table.
  #
  # Layout facts come from the layout's mushaf in the content database. The page count is the
  # mushaf's own count, never its number of page rows: one mushaf has more page rows than pages.
  # The font is the published font that the resource requires.
  class Comparison
    Table = Data.define(:columns, :rows)
    Row = Data.define(:resource, :pages, :lines_per_page, :font)

    # `resources` preload `resource_content` and `downloadable_related_resources: :related_resource`.
    def initialize(type, resources)
      @type = type
      @resources = resources
    end

    def call
      columns = Taxonomy.comparison_columns(@type)
      return if columns.empty?

      mushafs = @type.key == 'mushaf-layout' ? MushafLayouts::Page.mushafs_for(@resources) : {}
      rows = @resources.map do |resource|
        mushaf = mushafs[resource.id]
        Row.new(resource:, pages: mushaf&.pages_count, lines_per_page: mushaf&.lines_per_page, font: font_of(resource))
      end
      Table.new(columns:, rows:)
    end

    private

    def font_of(resource)
      resource.downloadable_related_resources
              .select(&:requires?)
              .map(&:related_resource)
              .find { |related| related&.published && related.resource_type == 'font' }
    end
  end
end
