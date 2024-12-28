module LayoutExporter
  class PageLookup < Base
    def export(rub: false, manzil: false)
      folder = get_mushaf_file_name
      export_path = "tmppage_lookup"
      FileUtils.mkdir_p export_path
      page_lookup = {}

      Verse.unscoped.order('id asc').each do |verse|
        page_lookup[verse.chapter_id] ||= {}
        first_word = verse.mushaf_words.where(mushaf_id: mushaf.id).order('page_number asc').first
        page_lookup[verse.chapter_id][verse.verse_number] = first_word.page_number
      end

      File.open("#{export_path}/#{folder}.json", "wb") do |f|
        f << JSON.generate(page_lookup, { state: JsonNoEscapeHtmlState.new })
      end

      "#{export_path}/#{folder}.json"
    end
  end
end