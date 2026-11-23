# frozen_string_literal: true

module Previews
  # One page of a mushaf as a preview draws it: its lines (MushafLayouts::Page), the font of its
  # text, the fonts of surah-name and bismillah lines, and the page each surah starts on, for
  # page navigation. Layouts and the one-font-per-page fonts both show one.
  class MushafPage
    Value = Data.define(:number, :pages_count, :font_code, :text_font, :surah_name_font, :surah_header_font,
                        :bismillah_font, :lines, :surahs)
    Surah = Data.define(:number, :name, :page)

    # The block gives the font of the page's text for the page number shown (after clamping).
    def self.build(mushaf, page_param, fonts:, &text_font)
      page = MushafLayouts::Page.new(mushaf, page_param)

      Value.new(
        number: page.number, pages_count: mushaf.pages_count, font_code: mushaf.default_font_name,
        text_font: text_font.call(page.number),
        surah_name_font: fonts.named('surah-name-v4'), surah_header_font: fonts.named('quran-common'),
        bismillah_font: fonts.named('bismillah'),
        lines: page.lines, surahs: surahs(mushaf)
      )
    end

    # Each surah with the page its first word is on in this mushaf (nil when the mushaf lacks it).
    def self.surahs(mushaf)
      first_words = Word.joins(:verse).where(position: 1, verses: { verse_number: 1 }).pluck(:id, 'verses.chapter_id')
      pages = MushafWord.where(mushaf_id: mushaf.id, word_id: first_words.map(&:first))
                        .pluck(:word_id, :page_number).to_h
      page_by_chapter = first_words.to_h { |word_id, chapter_id| [chapter_id, pages[word_id]] }

      Chapter.order(:id).pluck(:id, :name_simple).map do |id, name|
        Surah.new(number: id, name: name, page: page_by_chapter[id])
      end
    end
  end
end
