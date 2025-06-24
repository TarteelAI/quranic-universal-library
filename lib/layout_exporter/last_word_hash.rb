=begin
Usage
s=LayoutExporter::LastWordHash.new mushaf_id: 19
s.export
=end

module LayoutExporter
  class LastWordHash < Base
    def export
      folder = get_mushaf_file_name
      export_path = "tmp/layout-data/last-word-hash"
      FileUtils.mkdir_p export_path

      hash = []
      pages = MushafPage
        .where(mushaf: mushaf)
        .includes(:last_word)
        .order("page_number ASC")

      pages.each do |page|
        s, a, w = page.last_word.location.split(':').map(&:to_i)

        # Index start from zero, so have to offset by 1
        offset = if page.last_word.word?
                   1
                 else
                   2
                 end

        hash.push "#{s}-#{a}-#{w - offset}"
      end

      File.open("#{export_path}/#{folder}.js", "wb") do |f|
        f.puts "export const MUSHAF_PAGE_LAST_WORD_HASHES = ["
        hash.each do |h|
          f.puts "\"#{h}\","
        end
        f.puts "];"
      end

      "#{export_path}/#{folder}.js"
    end
  end
end