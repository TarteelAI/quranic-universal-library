# frozen_string_literal: true

module Catalog
  # /resources/:type, while the `catalog` page group is on (PageGroups). An unknown type is a 404.
  #
  # A type with more than SEARCH_ABOVE published resources is searched (Catalog::SearchQuery):
  # the query string's `q`, `language` and `page` pick one page of PER_PAGE cards, recommended
  # first and older versions last, so the page's sections keep their order across pages.
  class TypesController < InertiaController
    SEARCH_ABOVE = 48
    PER_PAGE = 24

    def show
      @type = Taxonomy.type(params[:type]) or raise ActiveRecord::RecordNotFound, "Unknown type #{params[:type]}"
      @types = Taxonomy.types
      @resources = ResourcesQuery.new(type: @type.key).call
      @comparison = Comparison.new(@type, @resources).call
      @total = @resources.size
      @search = (search if @total > SEARCH_ABOVE)

      render_inertia 'catalog/TypePage', meta: page_meta(
        title: "#{@type.title} - QUL",
        description: @type.description,
        json_ld: {
          '@type': 'CollectionPage',
          isPartOf: { '@type': 'WebSite', name: PageMeta::SITE_NAME, url: SeoHelper::HOST },
        },
      )
    end

    private

    # Narrows @resources to one page of matches and returns the search state.
    def search
      filters = SearchFilters.from(request.query_parameters.slice('q', 'language', 'page'))
      result = SearchQuery.new(filters.with(type: @type.key, sort: 'name')).call
      pages = pages_of(result.matches)
      page = filters.page.clamp(1, pages.size)

      @resources = pages[page - 1]
      search_state(result, page, pages.size)
    end

    def search_state(result, page, pages)
      names = result.languages.to_h { |language| [language.iso_code, language.name] }
      {
        q: result.filters.q, language: result.filters.language, page: page, pages: pages, matches: result.total,
        languages: result.facets[:language].map { |key, count| { key: key, name: names.fetch(key), count: count } },
      }
    end

    # The type's resources (with what the cards read preloaded) in the order of the search rows,
    # recommended first and older versions last, in pages; one empty page when nothing matches.
    def pages_of(rows)
      cards = @resources.index_by(&:id)
      ranked = rows.map { |row| cards.fetch(row.resource.id) }.sort_by.with_index { |card, index| [rank(card), index] }
      ranked.each_slice(PER_PAGE).to_a.presence || [[]]
    end

    def rank(resource)
      return 0 if resource.recommended
      return 2 if resource.legacy? || resource.superseded?

      1
    end
  end
end
