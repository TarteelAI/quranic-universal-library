# frozen_string_literal: true

module Catalog
  # /resources, while the `catalog` page group is on (PageGroups): catalog search. The query
  # string holds the filters (Catalog::SearchFilters); values it does not know are ignored.
  class ResourcesController < InertiaController
    DESCRIPTION = 'Download Quran data for your app: translations, tafsirs, recitations, Quran scripts, ' \
                  'fonts, mushaf layouts and more. Search the catalog and filter it by type, language and format.'

    def index
      search = SearchQuery.new(SearchFilters.from(request.query_parameters)).call

      render_inertia 'catalog/CatalogPage', locals: search.to_h, meta: page_meta(
        title: 'Resources - QUL',
        description: DESCRIPTION,
        json_ld: {
          '@type': 'CollectionPage',
          isPartOf: { '@type': 'WebSite', name: PageMeta::SITE_NAME, url: SeoHelper::HOST }
        }
      )
    end
  end
end
