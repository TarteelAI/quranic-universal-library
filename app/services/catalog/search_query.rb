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
    FACETS = [:category, :type, :language, :script, :format, :granularity, :status].freeze

    # One published resource with what search reads: its language (the CMS row's, else the
    # content row's), its formats and download total over published files, the date of its
    # last update and its search text.
    Row = Data.define(:resource, :language, :formats, :downloads, :updated_at, :text)

    # `filters` are the filters applied (a language no published resource has is dropped);
    # `matches` every matching row in order, `results` the rows of `page`; `facets` maps each
    # facet to {value => count}, where a count is the total that selecting that value gives,
    # under the other filters; `languages` are the languages of the published catalog. With no
    # sort and no query, matches are ordered by category and `groups` holds one Group for each
    # category on the page, in order; otherwise it is nil.
    Result = Data.define(:filters, :matches, :results, :total, :page, :pages, :facets, :languages, :groups)

    # A category's run of results on the page: `count` rows here, `total` over every page.
    Group = Data.define(:category, :total, :count)

    CATEGORY_ORDER = Taxonomy::CATEGORIES.keys.each_with_index.to_h.freeze

    def initialize(filters, per_page: PER_PAGE)
      @filters = filters
      @per_page = per_page
    end

    def call # rubocop:disable Metrics/AbcSize -- one pipeline: search, filter, sort, page, count
      rows = load_rows
      languages = rows.filter_map(&:language).uniq.sort_by(&:name)
      filters = @filters
      filters = filters.with(language: nil) if languages.none? { |language| language.iso_code == filters.language }

      tokens = TextKey.call(filters.q).split
      found = rows.select { |row| tokens.all? { |token| row.text.include?(token) } }
      order = order(filters, tokens)
      matches = sort(found.select { |row| FACETS.all? { |facet| match?(row, facet, filters) } }, order)
      pages = [(matches.size / @per_page.to_f).ceil, 1].max
      page = filters.page.clamp(1, pages)
      results = matches[(page - 1) * @per_page, @per_page]

      Result.new(
        filters: filters.with(page: page), matches: matches, results: results,
        total: matches.size, page: page, pages: pages,
        facets: FACETS.index_with { |facet| counts(found, facet, filters) }, languages: languages,
        groups: groups(matches, results, order),
      )
    end

    private

    def load_rows # rubocop:disable Metrics/AbcSize -- the fixed set of queries named above
      resources = DownloadableResource.published.preload(:downloadable_resource_tags).to_a
      files = DownloadableFile.where(published: true, downloadable_resource_id: resources.map(&:id))
        .group_by(&:downloadable_resource_id)
      content_languages = ResourceContent.where(id: resources.filter_map(&:resource_content_id))
        .pluck(:id, :language_id).to_h
      languages = Language.where(id: (resources.map(&:language_id) + content_languages.values).compact).index_by(&:id)

      resources.map do |resource|
        language = languages[resource.language_id || content_languages[resource.resource_content_id]]
        build_row(resource, language, files.fetch(resource.id, []))
      end
    end

    def build_row(resource, language, files)
      Row.new(
        resource: resource, language: language,
        formats: Taxonomy.formats_of(files.map(&:file_type)),
        downloads: files.sum(&:total_download_count),
        updated_at: files.map(&:updated_at).max || resource.updated_at,
        text: search_text(resource, language),
      )
    end

    def search_text(resource, language)
      type = Taxonomy.type(resource.resource_type)
      parts = [resource.display_name, resource.name, type&.label, type&.title, language&.name, language&.native_name,
               *resource.downloadable_resource_tags.map(&:name),]
      parts.filter_map { |part| TextKey.call(part).presence }.uniq.join(' | ')
    end

    # No sort and no query: by category, most downloaded first in each.
    def order(filters, tokens)
      filters.sort || (tokens.empty? ? :category : 'popular')
    end

    def category(row)
      Taxonomy.type(row.resource.resource_type).category.key
    end

    def category_rank(row)
      CATEGORY_ORDER.fetch(category(row))
    end

    def groups(matches, results, order)
      return unless order == :category

      totals = matches.map { |row| category(row) }.tally
      results.chunk { |row| category(row) }.map do |key, rows|
        Group.new(category: Taxonomy::CATEGORIES.fetch(key), total: totals.fetch(key), count: rows.size)
      end
    end

    def values(row, facet)
      case facet
      when :category then [category(row)]
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
      case order
      when 'name' then rows.sort_by { |row| name_key(row) }
      when 'updated' then rows.sort_by { |row| [-row.updated_at.to_f, *name_key(row)] }
      when :category then rows.sort_by { |row| [category_rank(row), -row.downloads, *name_key(row)] }
      else rows.sort_by { |row| [-row.downloads, *name_key(row)] }
      end
    end

    def name_key(row)
      [TextKey.call(row.resource.display_name), row.resource.id]
    end
  end
end
