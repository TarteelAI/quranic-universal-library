# frozen_string_literal: true

module Dev
  # Spike page for story 001-04: one page of a published mushaf layout, rendered in React from the
  # page's word rows with the page's own font. Its route exists where the Inertia sample's does.
  class MushafPagesController < InertiaController
    def show
      resource = DownloadableResource.published.where(resource_type: 'mushaf-layout').find(params[:id])
      mushaf = MushafLayouts::Page.mushaf_for(resource)
      raise ActiveRecord::RecordNotFound, "No mushaf for layout #{resource.id}" unless mushaf

      page = MushafLayouts::Page.new(mushaf, params.fetch(:page, 1))
      fonts = Fonts::UrlResolver.new(cdn_host: QulQuranRecord::CDN_HOST)

      @resource_id = resource.id
      @name = resource.name
      @font_code = mushaf.default_font_name
      @page = page.number
      @pages_count = mushaf.pages_count
      @lines = page.lines
      @text_font = fonts.named(mushaf.default_font_name, page: page.number)
      @surah_name_font = fonts.named('surah-name-v4')
      @surah_header_font = fonts.named('quran-common')
      @bismillah_font = fonts.named('bismillah')

      render_inertia 'dev/MushafPage', meta: [{ title: "#{resource.name}, page #{page.number} - QUL" }]
    end
  end
end
