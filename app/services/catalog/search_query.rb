# frozen_string_literal: true

module Catalog
  # Catalog search: the published catalog filtered by Catalog::SearchFilters, with a total, one
  # page of results and facet counts. It depends on no controller, request or session, so the
  # public API can reuse it.
  #
  # The published catalog is a few hundred rows, and the text to match spans two databases, so
  # it is loaded once per call in a fixed number of queries (resources, files and tags from the
  # CMS database; content rows and languages from the content database, keyed by id) and then
  # searched, filtered, counted, sorted and paged in Ruby. Nothing is kept between calls. If the
  # catalog grows into the thousands, filtering moves into SQL behind this interface.
  class SearchQuery
    PER_PAGE = 24

    # The filters with facet counts. The script family takes several values; the others one.
    FACETS = %i[type language script format granularity status].freeze

    # One published resource with what search reads: its language (the CMS row's, else the
    # content row's), its formats and download total over published files, the date of its
    # last update and its search text.
    Row = Data.define(:resource, :language, :formats, :downloads, :updated_at, :text)

    # `filters` are the filters applied (a language no published resource has is dropped);
    # `matches` every matching row in order, `results` the rows of `page`; `facets` maps each
    # facet to {value => count}, where a count is the total that selecting that value gives,
    # under the other filters; `languages` are the languages of the published catalog.
    Result = Data.define(:filters, :matches, :results, :total, :page, :pages, :facets, :languages)

    def initialize(filters, per_page: PER_PAGE)
      @filters = filters
      @per_page = per_page
    end

    def call
      rows = load_rows
      languages = rows.filter_map(&:language).uniq.sort_by(&:name)
      filters = @filters
      filters = filters.with(language: nil) if languages.none? { |language| language.iso_code == filters.language }

      tokens = TextKey.call(filters.q).split
      found = rows.select { |row| tokens.all? { |token| row.text.include?(token) } }
      matches = sort(found.select { |row| FACETS.all? { |facet| match?(row, facet, filters) } }, filters.sort)
      pages = [(matches.size / @per_page.to_f).ceil, 1].max
      page = filters.page.clamp(1, pages)

      Result.new(
        filters: filters.with(page: page), matches: matches, results: matches[(page - 1) * @per_page, @per_page],
        total: matches.size, page: page, pages: pages,
        facets: FACETS.index_with { |facet| counts(found, facet, filters) }, languages: languages
      )
    end

    private

    def load_rows
      resources = DownloadableResource.published.preload(:downloadable_resource_tags).to_a
      files = DownloadableFile.where(published: true, downloadable_resource_id: resources.map(&:id))
                              .group_by(&:downloadable_resource_id)
      content_languages = ResourceContent.where(id: resources.map(&:resource_content_id).compact)
                                         .pluck(:id, :language_id).to_h
      languages = Language.where(id: (resources.map(&:language_id) + content_languages.values).compact).index_by(&:id)

      resources.map do |resource|
        language = languages[resource.language_id || content_languages[resource.resource_content_id]]
        build_row(resource, language, files.fetch(resource.id, []))
      end
    end

    def build_row(resource, language, files)
      type = Taxonomy.type(resource.resource_type)
      text = [resource.display_name, resource.name, type&.label, type&.title, language&.name, language&.native_name,
              *resource.downloadable_resource_tags.map(&:name)]
      Row.new(
        resource: resource, language: language,
        formats: Taxonomy.formats_of(files.map(&:file_type)),
        downloads: files.sum(&:total_download_count),
        updated_at: files.map(&:updated_at).max || resource.updated_at,
        text: text.filter_map { |part| TextKey.call(part).presence }.uniq.join(' | ')
      )
    end

    def values(row, facet)
      case facet
      when :type then [row.resource.resource_type]
      when :language then [row.language&.iso_code]
      when :script then [row.resource.script_family]
      when :format then row.formats
      when :granularity then [row.resource.cardinality_type]
      when :status then [row.resource.status]
      end
    end

    def selected(facet, filters)
      Array(filters.public_send(facet))
    end

    def match?(row, facet, filters)
      chosen = selected(facet, filters)
      chosen.empty? || values(row, facet).intersect?(chosen)
    end

    # Value counts of one facet over the rows that match every other filter. Selected values
    # with no rows are kept, with 0.
    def counts(rows, facet, filters)
      others = FACETS - [facet]
      tally = rows.select { |row| others.all? { |other| match?(row, other, filters) } }
                  .flat_map { |row| values(row, facet).compact }.tally
      selected(facet, filters).each { |value| tally[value] ||= 0 }
      tally.sort_by { |value, count| [-count, value] }.to_h
    end

    def sort(rows, order)
      by_name = ->(row) { [TextKey.call(row.resource.display_name), row.resource.id] }
      case order
      when 'name' then rows.sort_by(&by_name)
      when 'updated' then rows.sort_by { |row| [-row.updated_at.to_f, *by_name.call(row)] }
      else rows.sort_by { |row| [-row.downloads, *by_name.call(row)] }
      end
    end
  end
end
