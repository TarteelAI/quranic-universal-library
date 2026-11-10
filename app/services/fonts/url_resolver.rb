# frozen_string_literal: true

module Fonts
  # The one rule that turns a font into its files on the CDN, for the new pages.
  #
  # A font is a set of base paths under `<cdn>/qul/fonts/`, one per format, in the shape a font
  # resource's meta data stores them (`'woff2' => 'UthmanicHafs_V22'`). The file is the base path
  # plus the format's extension. A base path that ends in its own format name
  # (`quran_fonts/v2/woff2`) is a folder with one file per mushaf page, `p<page>.<ext>`.
  # Sources come in the order a browser should try them: woff2, woff, ttf, otf.
  class UrlResolver
    FORMATS = { 'woff2' => 'woff2', 'woff' => 'woff', 'ttf' => 'truetype', 'otf' => 'opentype' }.freeze

    # Paths and family names end up in a CSS block, and font resource meta is edited by hand:
    # they keep only the characters a path or a family name needs.
    UNSAFE = %r{[^\w/.-]}

    Source = Struct.new(:url, :format, keyword_init: true)
    Font = Struct.new(:family, :sources, :per_page, keyword_init: true) do
      def url(extension)
        sources.find { |source| source.url.end_with?(".#{extension}") }&.url
      end
    end

    def self.per_page(folder)
      %w[woff2 woff ttf].to_h { |extension| [extension, "#{folder}/#{extension}"] }
    end

    # Fonts that layouts and scripts name by code (a mushaf's font name, a script's `font` or
    # `font-face` meta key), and the fonts that draw surah-name and bismillah lines. The paths
    # are the ones the old pages' stylesheets load for the same code.
    NAMED = {
      'v1' => per_page('quran_fonts/v1-optimized'),
      'v2' => per_page('quran_fonts/v2'),
      'v4-tajweed' => per_page('quran_fonts/v4-tajweed'),
      'qpc-hafs' => { 'woff2' => 'UthmanicHafs_V22', 'ttf' => 'UthmanicHafs_V22' },
      'qpc-nastaleeq' => { 'woff2' => 'nastaleeq/KFGQPCNastaleeq-Regular', 'ttf' => 'nastaleeq/KFGQPCNastaleeq-Regular' },
      'indopak-nastaleeq' => { 'woff2' => 'nastaleeq/indopak-nastaleeq-waqf-lazim' },
      'mushaf-indopak-nastaleeq-hanafi-compressed' => {
        'woff2' => 'nastaleeq/Hanafi/compressed-v4.2.2/with-waqf-lazmi/font'
      },
      'digitalkhatt' => { 'otf' => 'dk/DigitalKhattQuranicV1' },
      'me_quran' => { 'ttf' => 'me_quran_volt_newmet' },
      'pdms-saleem' => { 'ttf' => 'pdms-saleem-quranfont' },
      'qpc-warsh' => { 'woff2' => 'quran_fonts/qpc/uthmanic-warsh-v21', 'ttf' => 'quran_fonts/qpc/uthmanic-warsh-v21' },
      'surah-name-v4' => {
        'woff2' => 'surah-names/v4/surah-name-v4', 'woff' => 'surah-names/v4/surah-name-v4',
        'ttf' => 'surah-names/v4/surah-name-v4'
      },
      'quran-common' => { 'woff2' => 'common/quran-common', 'woff' => 'common/quran-common', 'ttf' => 'common/quran-common' },
      'bismillah' => { 'woff2' => 'bismillah/bismillah' }
    }.freeze

    # Other spellings of a code found in mushaf font names and script meta.
    ALIASES = { 'indopak' => 'indopak-nastaleeq', 'me-quran' => 'me_quran' }.freeze

    def initialize(cdn_host:)
      @root = "#{cdn_host}/qul/fonts"
    end

    # A font resource, from its resource content's meta data.
    def from_meta(meta, page: 1)
      paths = meta.slice(*FORMATS.keys).select { |_, path| path.to_s.strip != '' }
      return if paths.empty?

      build(paths, meta['font-face'].to_s.sub(/\Ap\d+-/, ''), page)
    end

    # A font named by code: a mushaf's font name, a script's font, or `surah-name-v4`,
    # `quran-common` and `bismillah`. Nil when the code has no font (image and SVG layouts).
    def named(code, page: 1)
      name = code.to_s.split(' or ').first.to_s.strip
      name = ALIASES.fetch(name, name)
      paths = NAMED[name]
      paths && build(paths, name, page)
    end

    # A Quran script resource: its `font-face` meta key, else its `font` key.
    def for_script(meta, page: 1)
      named(meta['font-face'].to_s.strip.empty? ? meta['font'] : meta['font-face'], page: page)
    end

    private

    def build(paths, font_face, page)
      raise ArgumentError, "page must be 1 or more, got #{page.inspect}" unless page.is_a?(Integer) && page >= 1

      per_page = paths.any? { |extension, path| File.basename(path) == extension }
      sources = FORMATS.filter_map do |extension, format|
        path = paths[extension]
        next unless path

        file = (per_page ? "#{path}/p#{page}" : path).gsub(UNSAFE, '')
        Source.new(url: "#{@root}/#{file}.#{extension}", format: format)
      end

      Font.new(family: family(paths.values.first, font_face, per_page, page).gsub(UNSAFE, ''), sources:, per_page:)
    end

    def family(path, font_face, per_page, page)
      return "#{File.basename(File.dirname(path))}-p#{page}" if per_page

      font_face.empty? ? File.basename(path) : font_face
    end
  end
end
