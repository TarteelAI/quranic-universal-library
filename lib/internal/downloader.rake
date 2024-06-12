namespace :downloader do
  task fix_tajweeed_html: :environment do
    def recode_windows_1252_to_utf8(string)
      string.gsub(/[\u0080-\u009F]/) {|x| x.getbyte(1).chr.force_encoding('windows-1256').encode('utf-8') }
    end

    1.upto(604) do |page|
      url = "http://transliteration.org/quran/WebSite_CD/MixDictionary/#{page.to_s.rjust(3, '0')}.asp"

      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient.get(url)
      end

      content = recode_windows_1252_to_utf8 File.read("data/tajweed-transliteration/#{page}.html")
      docs = Nokogiri::HTML::DocumentFragment.parse(content)

      File.open("data/tajweed-transliteration/#{page}-clean.html", "wb") do |f|
        docs.search("a, audio").remove
        body = docs.search("table")[1].to_s
        f << "<html><head><meta charset='UTF-8'><link rel='styleSheet' href='style.css'/></head><body>#{body}</body></html>"
      end

      `iconv -f windows-1256 -t utf-8 data/tajweed-transliteration/#{page}.html > data/tajweed-transliteration/#{page}-utf.html`

      docs = Nokogiri::HTML::DocumentFragment.parse(response.to_s)

      tds = docs.search("td[width='50%']")
      transliterations = tds[2].search("font span[title]")
      text = transliterations[0].children.to_s
      translation = transliterations[0].attr('title').split("/")

      arabic = tds[1].search("font").children.to_s


      File.open("data/tajweed-transliteration/fixed/#{page}.html", "wb") do |f|
        f << response.to_s
      end

      puts page
    end

    1.upto(10) do |page|
      html = File.read("data/tajweed/#{page}.html")
      docs = Nokogiri::HTML::DocumentFragment.parse(html)

      text = docs.search("#quran_text_t").inner_html.gsub(/[﴿﴾]/, '')
                 .gsub("ڪِ", "كِ") # kaf
                 .gsub("ذَ ‍", "ذَٰ") #za with dagger alif
                 .gsub(1611.chr, 1623.chr) # double pesh
                 .gsub(" ٗ", 1623.chr)
                 .gsub(1706.chr, 03103.chr)
                 .gsub("ى", "ى")
                 .gsub(03301.chr, 03107.chr)
                 .gsub("ٱ", "<span r=1>ٱ</span>")

      html = text
      text = text.gsub("\u200D", "") # remove zero width joiner

      text = text.gsub(">#{03127.chr}", ">#{03113.chr}&zwj;")

      #.gsub("ہِ", "هِ") # small ha with zeer
      # .gsub("ہۡ", "هۡ") # small ha with

      File.open("data/tajweed-html/#{page}.html", "wb") do |file|
        file << "<html><body>"

        file << "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'><link rel='stylesheet' href='style.css'><quran>"
        file << "<div class=row><div class=col-6><p>Without zero width joiner</p>"
        file << text.html_safe
        file << "</div><div class=col-6><p>With zero width joiner</p>"
        file << html.html_safe
        file << "</div><div></quran></body></html>"
      end
    end
  end

  task download_tajweed_img: :environment do
    require 'typhoeus'
    hydra = Typhoeus::Hydra.new

    98.upto(604) do |page|
      url =  "https://easyquran.com/quran-jpg/images/#{page}.jpg"

      request = Typhoeus::Request.new(url)
      hydra.queue(request)
      hydra.run

      File.open("data/tajweed/#{page}.jpg", "wb") do |file|
        file << request.response.body
      end

      puts page
    end
  end

  task download_recite_quran: :environment do
    require 'typhoeus'
    hydra = Typhoeus::Hydra.new
    FileUtils.mkdir_p "data/words-data/corpus-data/recitequran"

    604.upto(668) do |page|
      url = "https://recitequran.com/ajx_load.php?WBW=english&ColorText=1&Translations=&nid=#{page}"

      request = Typhoeus::Request.new(url)
      hydra.queue(request)
      hydra.run


      File.open("data/words-data/corpus-data/recitequran/#{page}.json", "wb") do |file|
        file << request.response.body
      end
    end
  end

  task download_quranacademy: :environment do
    require 'typhoeus'
    hydra = Typhoeus::Hydra.new

    # tajweed
    Verse.order("verse_index ASC").each do |verse|
      requests = verse.words.map do |word|
        if word.word?
          puts word.location
          surah, ayah, num = word.location.split(':')

          img_url = "https://en.quranacademy.org/quran/words-own/tajweed/#{surah}/#{surah}-#{ayah}-#{num}.png"

          request = Typhoeus::Request.new(img_url, params: { w: word.location })
          hydra.queue(request)
          request
        end
      end

      hydra.run

      requests.each do |request|
        if request
          location = request.options[:params][:w]
          surah, ayah, word = location.split(':')
          path = "../community-data/words-data/quranacademy/tajweed/#{surah}/#{ayah}/"
          FileUtils.mkdir_p path

          File.open("#{path}/#{word}.png", "wb") do |file|
            file << request.response.body
          end
        end
      end
    end

    # black
    Verse.order("verse_index ASC").each do |verse|
      requests = verse.words.map do |word|
        if word.word?
          puts word.location
          surah, ayah, num = word.location.split(':')

          img_url = "https://en.quranacademy.org/quran/words-own/black/#{surah}/#{surah}-#{ayah}-#{num}.png"

          request = Typhoeus::Request.new(img_url, params: { w: word.location })
          hydra.queue(request)
          request
        end
      end

      hydra.run

      requests.each do |request|
        if request
          location = request.options[:params][:w]
          surah, ayah, word = location.split(':')
          FileUtils.mkdir_p "data/word-translations/word-corpus-data/quranacademy/black/#{surah}/#{ayah}/"

          File.open("data/word-translations/word-corpus-data/quranacademy/black/#{surah}/#{ayah}/#{word}.png", "wb") do |file|
            file << request.response.body
          end
        end
      end
    end
  end

  task download_corpus_word_imgs: :environment do
    require 'typhoeus'
    hydra = Typhoeus::Hydra.new

    Verse.order("verse_index ASC").where("id > 4410").each do |verse|
      requests = verse.words.map do |word|
        if word.word?
          puts word.location
          data = File.read("data/word-corpus-data/#{verse.verse_key.tr(':', '/')}/#{word.position}.html")
          parsed_html = Nokogiri.parse(data)

          FileUtils.mkdir_p "data/word-translations/word-corpus-data/word-imgs/#{verse.verse_key.tr(':', '/')}/w/"

          img_url = parsed_html.search(".tokenLink img")
          img_url = "https://corpus.quran.com/#{img_url.first.attributes["src"].value}"

          request = Typhoeus::Request.new(img_url, params: { w: word.location })
          hydra.queue(request)
          request
        end
      end

      hydra.run

      requests.each do |request|
        if request
          location = request.options[:params][:w]
          surah, ayah, word = location.split(':')

          File.open("data/word-translations/word-corpus-data/word-imgs/#{surah}/#{ayah}/w/#{word}.png", "wb") do |file|
            file << request.response.body
          end
        end
      end
    end
  end

  task download_corpus_data: :environment do
    require 'fileutils'
    require 'typhoeus'
    base_dir = "data/word-corpus-data"
    FileUtils::mkdir_p base_dir

    hydra = Typhoeus::Hydra.new

    Verse.order("verse_index ASC").each do |verse|
      FileUtils::mkdir_p "#{base_dir}/#{verse.verse_key.tr(':', '/')}"
      puts verse.verse_key

      requests = verse.words.map do |word|
        puts word.location
        request = nil
        if word.word?
          url = "https://corpus.quran.com/wordmorphology.jsp?location=(#{word.location})"
          request = Typhoeus::Request.new(url, params: { w: word.position })
          hydra.queue(request)
        end
        request
      end

      hydra.run

      requests.each do |request|
        if request
          position = request.options[:params][:w]
          File.open("#{base_dir}/#{verse.verse_key.tr(':', '/')}/#{position}.html", "wb") do |file|
            file << request.response.body
          end
        end
      end
    end
  end

  task download_quranwbw: :environment do
    require 'fileutils'

    # Download WBW translations
    url = "https://data.quranwbw.com/%{SURAH_ID}/word-translations/%{LANGUAGE}.json?v1636066953"
    base_dir = "data/word-translations"

    FileUtils::mkdir_p base_dir

    languages = ['english', 'urdu', 'hindi', 'arabic', 'indonesian', 'bangla', 'turkish', 'tamil', 'german', 'russian', 'ingush']

    languages.each do |lang|
      FileUtils::mkdir_p "#{base_dir}/#{lang}"
      1.upto(114) do |chapter|
        translation_url = format(url, LANGUAGE: lang, SURAH_ID: chapter)

        response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
          RestClient.get(translation_url)
        end

        File.open("#{base_dir}/#{lang}/#{chapter}.json", "wb") do |file|
          file << response.body
        end

        puts "#{lang} - #{chapter}"
      end
    end

    # Download corpus
    # https://data.quranwbw.com/2/word-corpus/2.json

    FileUtils::mkdir_p "#{base_dir}/corpus"

    1.upto(114) do |id|
      FileUtils::mkdir_p "#{base_dir}/corpus/#{id}"
    end

    Verse.find_each do |verse|
      next if verse.chapter_id < 33
      url = "https://data.quranwbw.com/#{verse.chapter_id}/word-corpus/#{verse.verse_number}.json"
      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient.get(url)
      end

      File.open("#{base_dir}/corpus/#{verse.chapter_id}/#{verse.verse_number}.json", "wb") do |file|
        file << response.body
      end

      puts verse.verse_key
    end

  end
end