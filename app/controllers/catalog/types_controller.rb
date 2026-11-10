# frozen_string_literal: true

module Catalog
  # /resources/:type, while the `catalog` page group is on (PageGroups). An unknown type is a 404.
  class TypesController < InertiaController
    def show
      @type = Taxonomy.type(params[:type]) or raise ActiveRecord::RecordNotFound, "Unknown type #{params[:type]}"
      @types = Taxonomy.types
      @resources = ResourcesQuery.new(type: @type.key).call
      @comparison = Comparison.new(@type, @resources).call

      render_inertia 'catalog/TypePage', meta: page_meta(
        title: "#{@type.title} - QUL",
        description: @type.description,
        json_ld: {
          '@type': 'CollectionPage',
          isPartOf: { '@type': 'WebSite', name: PageMeta::SITE_NAME, url: SeoHelper::HOST }
        }
      )
    end
  end
end
