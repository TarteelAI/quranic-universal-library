# frozen_string_literal: true

module Previews
  # A mushaf layout: one page (`?page=`, clamped to the mushaf's pages), drawn from the page's
  # word rows with the layout's font. A layout without a font (SVG and image layouts) cannot be
  # drawn.
  class MushafLayout
    Preview = Data.define(:page) do
      def serializer = MushafLayoutResource
    end

    def initialize(resource, query, fonts: Previews.font_resolver)
      @resource = resource
      @query = query
      @fonts = fonts
    end

    def call
      mushaf = MushafLayouts::Page.mushaf_for(@resource)
      return Unavailable.new(reason: 'This layout has no mushaf data yet.') unless mushaf
      unless @fonts.named(mushaf.default_font_name)
        return Unavailable.new(reason: 'This layout is drawn with images, not a font, so it has no text preview yet.')
      end

      Preview.new(page: MushafPage.build(mushaf, @query['page'], fonts: @fonts) do |number|
        @fonts.named(mushaf.default_font_name, page: number)
      end)
    end
  end
end
