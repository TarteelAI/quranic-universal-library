=begin
Usage
s=LayoutExporter::AyahMetadata.new mushaf_id: 19
s.export
=end

module LayoutExporter
  class AyahMetadata < Base
    def export
      folder = get_mushaf_file_name
      export_path = "tmp/layout-data/ayah-metadata"
      FileUtils.mkdir_p export_path

      fractions = []
      chapter_fractions = []
      last_chapter = 1

      pages.each do |page|
        page_letters_count = page_text_length(page)

        page_verses(page).each do |v|
          if v.chapter_id != last_chapter
            fractions << chapter_fractions
            last_chapter = v.chapter_id
            chapter_fractions = []
          end

          text = ayah_text(v)
          ayah_letters_count = text.length
          words_letters_length = text.gsub(/\s+/, '').length
          fraction = ayah_letters_count.to_f / page_letters_count.to_f

          chapter_fractions << [words_letters_length, ayah_letters_count, fraction]
        end
      end


      fractions << chapter_fractions

      File.open("#{export_path}/#{folder}.json", "wb") do |f|
        f << JSON.generate(fractions, { state: JsonNoEscapeHtmlState.new })
      end

      "#{export_path}/#{folder}.json"
    end

    def page_text_length(page)
      simple_text = []
      page_verses(page).each do |v|
        simple_text << ayah_text(v)
      end

      simple_text.join().length
    end

    def page_verses(page)
      Verse
        .unscoped
        .where(
          verse_index: (page.first_verse_id..page.last_verse_id)
        )
        .order('verse_index asc')
    end

    def ayah_text(verse)
      QuranScript::ByVerse
        .where(
          verse_id: verse.id,
          resource_content_id: 1200
        )
        .first
        .text
    end

    def pages
      MushafPage
        .where(mushaf_id: mushaf.id)
        .order('page_number asc')
    end
  end
end