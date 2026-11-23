# frozen_string_literal: true

module Previews
  # A Quran script resource: a range of ayahs of one surah in the script's text and font
  # (`?surah=`, `?from=`, `?to=`; ten ayahs unless `to` says otherwise, at most twenty).
  #
  # Where the text comes from: a qira'at script has its own rows (QuranScript::ByVerse and
  # ByWord); an image script has one image per word; a glyph script (QPC V1, V2, V4) is drawn word
  # by word, each word in the font file of its mushaf page; any other script is a text column of
  # the ayah or the word rows. The font is the published font resource whose `script` meta names
  # the script's text type, else the font the script's own meta names.
  class Script
    RANGE = 10
    MAX_RANGE = 20

    # Glyph scripts: the column with the glyph codes and the column with the page they belong to.
    # V4 Tajweed uses the V2 glyph codes, drawn with the V4 page fonts.
    GLYPHS = {
      'code_v1' => %w[code_v1 page_number],
      'code_v2' => %w[code_v2 v2_page],
      'code_v4' => %w[code_v2 v2_page]
    }.freeze
    # Scripts whose text marks tajweed rules with <rule class="..."> tags.
    TAJWEED = %w[text_uthmani_tajweed].freeze

    Preview = Data.define(:granularity, :rendering, :font_code, :fonts, :surah, :from, :to, :ayahs, :surahs) do
      def serializer = ScriptResource
    end
    Ayah = Data.define(:key, :number, :text, :font, :words)
    Token = Data.define(:id, :text, :font, :image_url)

    # A text column of the ayah and word rows, or nil for anything else.
    def self.text_column(name)
      name.to_s if name.to_s.match?(/\A(text|code)_\w+\z/) && Verse.column_names.include?(name.to_s)
    end

    def initialize(resource, query, fonts: Previews.font_resolver)
      @resource = resource
      @query = query
      @fonts = fonts
      @content = resource.resource_content
      @meta = @content&.meta_data.to_h
      @text_type = @meta['text-type'].to_s
    end

    def call
      surahs = Previews.surahs
      surah = Previews.surah(@query, surahs)
      from, to = Previews.range(@query, surah.verses_count, size: RANGE, max: MAX_RANGE)

      ayahs = self.ayahs(Verse.where(chapter_id: surah.number, verse_number: from..to).order(:verse_number).to_a)
      return Unavailable.new(reason: "This script's text (#{@text_type}) has no preview yet.") unless ayahs

      Preview.new(granularity: word? ? 'word' : 'ayah', rendering:,
                  font_code: GLYPHS.key?(@text_type) ? @meta['font'] : nil,
                  fonts: @used_fonts.values.compact.uniq(&:family), surah:, from:, to:, ayahs:, surahs:)
    end

    private

    def word?
      @content&.word? || false
    end

    def image?
      @text_type.end_with?('_image_url') && ::Word.method_defined?(@text_type)
    end

    def rendering
      return 'image' if image?

      TAJWEED.include?(@text_type) ? 'html' : 'text'
    end

    # The ayahs with their text or their words; nil for a text type it cannot read.
    def ayahs(verses)
      @used_fonts = {}
      if @meta['qirat'].present? then qirat(verses)
      elsif image? then images(verses)
      elsif GLYPHS.key?(@text_type) then glyphs(verses)
      elsif (column = self.class.text_column(@text_type)) then text(verses, column)
      end
    end

    def images(verses)
      by_word(verses, []) { |word| token(word, nil, nil, image_url: word.public_send(@text_type)) }
    end

    def text(verses, column)
      family = font(1)&.family
      if word?
        by_word(verses, [column]) { |word| token(word, clean(word[column]), family) }
      else
        verses.map { |verse| ayah(verse, text: clean(verse[column]), font: family) }
      end
    end

    # Glyph codes are drawn word by word even for an ayah-level script: an ayah can run over two
    # pages, and each page's words are only in that page's font.
    def glyphs(verses)
      column, page_column = GLYPHS.fetch(@text_type)
      by_word(verses, [column, page_column]) { |word| token(word, word[column], font(word[page_column])&.family) }
    end

    def qirat(verses)
      family = font(1)&.family
      scope = { resource_content_id: @content.id, chapter_id: verses.first.chapter_id,
                verse_number: verses.map(&:verse_number) }
      if word?
        rows = QuranScript::ByWord.where(scope).order(:verse_number, :word_number).group_by(&:verse_number)
        verses.map do |verse|
          ayah(verse, words: rows.fetch(verse.verse_number, []).map { |row| token(row, row.text, family) })
        end
      else
        rows = QuranScript::ByVerse.where(scope).index_by(&:verse_number)
        verses.map { |verse| ayah(verse, text: rows[verse.verse_number]&.text, font: family) }
      end
    end

    def by_word(verses, columns, &token)
      words = ::Word.where(verse_id: verses.map(&:id)).reorder(:verse_id, :position)
                    .select(:id, :verse_id, :location, :char_type_id, :char_type_name, *columns).group_by(&:verse_id)
      verses.map { |verse| ayah(verse, words: words.fetch(verse.id, []).map(&token)) }
    end

    def token(row, text, font, image_url: nil)
      Token.new(id: row.id, text:, font:, image_url:)
    end

    def ayah(verse, text: nil, font: nil, words: [])
      Ayah.new(key: verse.verse_key, number: verse.verse_number, text:, font:, words:)
    end

    def clean(value)
      return value unless rendering == 'html'

      Rails::HTML5::SafeListSanitizer.new.sanitize(value.to_s, tags: %w[rule], attributes: %w[class])
    end

    # The font for a mushaf page (only glyph fonts differ by page), kept for the preview's font list.
    def font(page)
      @used_fonts.fetch(page) do
        meta = script_font_meta
        @used_fonts[page] = meta ? @fonts.from_meta(meta, page:) : @fonts.for_script(@meta, page:)
      end
    end

    # The meta of the published font resource made for this script's text type.
    def script_font_meta
      return @script_font_meta if defined?(@script_font_meta)

      fonts = DownloadableResource.published.where(resource_type: 'font').order(:id).preload(:resource_content)
      @script_font_meta = fonts.map { |font| font.resource_content&.meta_data.to_h }
                               .find { |meta| meta['script'] == @text_type }
    end
  end
end
