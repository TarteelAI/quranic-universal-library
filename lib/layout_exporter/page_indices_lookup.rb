=begin
Usage
s=LayoutExporter::PageIndicesLookup.new mushaf_id: 19
s.export
=end

module LayoutExporter
  class PageIndicesLookup < Base
    def export(hizb: false, manzil: false)
      folder = get_mushaf_file_name
      export_path = "tmp/layout-data/page-indices-lookup"
      FileUtils.mkdir_p export_path
      pages = []

      MushafPage.where(mushaf: mushaf).order('page_number ASC').each do |page|
        first_ayah = page.first_verse
        last_ayah = page.last_verse

        page_mapping = {
          juz: first_ayah.juz_number,
          hizb: hizb && first_ayah.hizb_number,
          rub:  first_ayah.rub_el_hizb_number,
          manzil: manzil && first_ayah.manzil_number,
          start: {
            surah: first_ayah.chapter_id,
            ayah: first_ayah.verse_number
          },
          end: {
            surah: last_ayah.chapter_id,
            ayah: last_ayah.verse_number
          }
        }

        pages << page_mapping.compact_blank
      end

      File.open("#{export_path}/#{folder}.json", "wb") do |f|
        f << JSON.generate(pages, { state: JsonNoEscapeHtmlState.new })
      end

      "#{export_path}/#{folder}.json"
    end
  end
end