# frozen_string_literal: true

module Previews
  # A font resource: a sample drawn in the font, the names its ligatures turn into glyphs, and
  # its glyphs (read from the font file in the browser). A font with one file per mushaf page
  # shows a page of its mushaf instead of a sample (`?page=`), in that page's file. `?view=`
  # opens the sample, the ligatures or the glyphs.
  #
  # The sample is Quran text in the encoding the font is made for: the script its meta names,
  # else the editor's sample text, else the script of a linked Quran script resource, else
  # Uthmani text. Al-Fatihah is the passage.
  class Font
    VIEWS = %w[sample ligatures glyphs].freeze
    SAMPLE_SURAH = 1
    FALLBACK_SCRIPT = 'text_uthmani'

    Preview = Data.define(:font, :view, :sample, :ligatures, :page) do
      def serializer = FontResource
    end
    Sample = Data.define(:text, :source)
    Ligature = Data.define(:name, :text)

    def initialize(resource, query, fonts: Previews.font_resolver)
      @resource = resource
      @query = query
      @fonts = fonts
      @meta = resource.resource_content&.meta_data.to_h
    end

    def call
      font = @fonts.from_meta(@meta)
      return Unavailable.new(reason: 'This font lists no font files.') unless font

      page = mushaf_page if font.per_page
      ligatures = self.ligatures
      view = @query['view'].presence_in(VIEWS)
      view = 'sample' if view.nil? || (view == 'ligatures' && ligatures.empty?)

      Preview.new(font: page&.text_font || font, view:, sample: page ? nil : sample, ligatures:, page:)
    end

    private

    # The mushaf whose layout code uses this font's page files (QPC V1, V2, V4).
    def mushaf_page
      code, = Fonts::UrlResolver::NAMED.find { |_code, paths| paths.any? { |format, path| @meta[format] == path } }
      mushaf = code && Mushaf.where(default_font_name: code, enabled: true).order(:id).first
      return unless mushaf

      MushafPage.build(mushaf, @query['page'], fonts: @fonts) { |number| @fonts.from_meta(@meta, page: number) }
    end

    def sample
      column = Script.text_column(@meta['script'])
      return quran_sample(column) if column && Script::TAJWEED.exclude?(column)
      return Sample.new(text: @meta['text'].strip, source: nil) if @meta['text'].present?

      quran_sample(linked_script_column || FALLBACK_SCRIPT)
    end

    def quran_sample(column)
      chapter = Chapter.find(SAMPLE_SURAH)
      text = Verse.where(chapter_id: chapter.id).order(:verse_number).pluck(column).compact.join(' ')
      Sample.new(text:, source: "Surah #{chapter.name_simple}, #{column}")
    end

    # The text column of a Quran script resource linked to this font, either way.
    def linked_script_column
      ids = DownloadableRelatedResource.where(downloadable_resource_id: @resource.id)
                                       .or(DownloadableRelatedResource.where(related_resource_id: @resource.id))
                                       .pluck(:downloadable_resource_id, :related_resource_id).flatten - [@resource.id]
      scripts = DownloadableResource.published.where(id: ids, resource_type: 'quran-script').order(:id)
                                    .preload(:resource_content)
      scripts.lazy.filter_map { |script| Script.text_column(script.resource_content&.meta_value('text-type')) }.first
    end

    def ligatures
      parsed = JSON.parse(@meta['ligatures'].presence || '{}')
      return [] unless parsed.is_a?(Hash)

      parsed.map { |name, text| Ligature.new(name: name.to_s, text: text.to_s) }
    rescue JSON::ParserError
      []
    end
  end
end
