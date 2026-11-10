# frozen_string_literal: true

module Catalog
  # While the `catalog` page group is on (PageGroups): catalog search at /resources, and the
  # detail page of each published resource at /resources/:type/:slug.
  #
  # Catalog search: the query string holds the filters (Catalog::SearchFilters); values it does
  # not know are ignored.
  #
  # Detail page: the slug URL is the only one. An id URL, a wrong type and the old tab and
  # copyright URLs redirect to it permanently, keeping the query string. `?tab=` names the open
  # tab; `?download=<file id>` (where sign-in returns to) starts that file's download. The
  # preview's own keys (Previews::QUERY_KEYS: the page, the surah and ayahs, the font view) go to
  # the deferred preview prop, which page navigation reloads on its own.
  class ResourcesController < InertiaController
    # The old tabs and the query of the new page that shows what they showed.
    OLD_TABS = {
      'docs' => { tab: 'data' }, 'licence' => { tab: 'licence' },
      'ligatures' => { view: 'ligatures' }, 'glyphs' => { view: 'glyphs' }
    }.freeze

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

    def show
      resource = ResourcePage.find(params[:slug])
      return redirect_to_page(resource, request.query_parameters) unless canonical?(resource)

      @page = ResourcePage.new(resource, viewer: current_user)
      @tab = @page.tab(params[:tab])
      @download_mode = DownloadMode.current
      @download = download_to_start(params[:download])
      @issue_url = @page.issue_url("#{SeoHelper::HOST}#{request.path}")
      # Only plain values: `?page[]=2` is not a page.
      @preview_query = request.query_parameters.slice(*Previews::QUERY_KEYS).select { |_, value| value.is_a?(String) }

      render_inertia 'catalog/ResourcePage', meta: page_meta(
        title: "#{resource.display_name} - #{@page.type.label} - QUL",
        description: @page.summary,
        json_ld: json_ld
      )
    end

    def tab
      redirect_to_page(ResourcePage.find(params[:slug]), OLD_TABS.fetch(params[:tab]))
    end

    def copyright
      redirect_to_page(ResourcePage.find(params[:slug]), tab: 'licence')
    end

    private

    def canonical?(resource)
      params[:type] == resource.resource_type && params[:slug] == resource.to_param
    end

    def redirect_to_page(resource, query)
      path = catalog_resource_path(type: resource.resource_type, slug: resource.to_param, **query.compact)
      redirect_to path, status: :moved_permanently
    end

    # The file sign-in returned for, when this viewer may download it now.
    def download_to_start(file_id)
      return if file_id.blank? || !@page.can_download?
      return if current_user.nil? && !DownloadMode.public?

      @page.files.find { |file| file.id.to_s == file_id }&.id
    end

    def json_ld
      {
        '@type': 'Dataset',
        isPartOf: { '@type': 'WebSite', name: PageMeta::SITE_NAME, url: SeoHelper::HOST },
        dateModified: @page.updated_on&.iso8601,
        distribution: @page.files.map do |file|
          { '@type': 'DataDownload', name: file.name, encodingFormat: file.format_label, contentSize: file.byte_size }
        end
      }.compact
    end
  end
end
