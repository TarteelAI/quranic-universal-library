# frozen_string_literal: true

module Start
  # The starter kits (Kits) while the `start` page group is on (PageGroups): the index and a page
  # for each kit. There is no old page: with the group off, both are 404s.
  class KitsController < InertiaController
    def index
      @kits = Kits.listed(Kits.all)

      render_inertia 'start/KitsPage', meta: page_meta(
        title: 'Starter kits - QUL',
        description: 'Curated sets of Quran data that work together: a mushaf reader, an IndoPak reader with Urdu, ' \
                     'recitation with highlighting and word by word learning.',
      )
    end

    def show
      @kit = Kits.find(params[:key]) || raise(ActiveRecord::RecordNotFound)
      # The kit's cards are catalog search results, so they read like the catalog's.
      rows = Catalog::SearchQuery.new(Catalog::SearchFilters.from({})).call.matches
      @entries = Kits.resolve(@kit, rows.index_by { |row| row.resource.slug })

      render_inertia 'start/KitPage', meta: page_meta(title: "#{@kit.title} - Starter kits - QUL",
                                                      description: @kit.blurb,)
    end
  end
end
