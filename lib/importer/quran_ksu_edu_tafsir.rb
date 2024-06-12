# i = Importer::QuranKsuEduTafsir.new
# i.download
module Importer
  class QuranKsuEduTafsir < Base
    # tafsir qortobi/qurtubi
    # https://quran.ksu.edu.sa/tafseer/qortobi-saadi/sura1-aya1.html
    def download
      FileUtils.mkdir_p("data/quranenc-tafsirs/qortobi/")
      Verse.order('id asc').find_each do |v|
        url = "https://quran.ksu.edu.sa/tafseer/qortobi-saadi/sura#{v.chapter_id}-aya#{v.verse_number}.html"

        next if File.exist?("data/quranenc-tafsirs/qortobi/#{v.verse_key}.json")

        File.open("data/quranenc-tafsirs/qortobi/#{v.verse_key}.json", "wb") do |file|
          text = get_html(url).body
          file.puts text

          puts v.verse_key
        end
      end
    end

    def import

    end
  end
end