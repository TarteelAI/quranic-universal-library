namespace :tajweed do
  task generate_mushaf_layout: :environemnt do
    mushaf = Mushaf.find(5) #qpc hafs
    tajweed_mushaf = Mushaf.new(mushaf.attributes.except('id', 'name'))
    tajweed_mushaf.name = "QPC Hafs with tajweed"
    tajweed_mushaf.save

    data = JSON.parse(File.read("../community-data/uthmani_tajweed.json"))
    words_mapping = { }

    data.each do |key, text|
      words_mapping[key] = text.gsub(/"/, '').split(' ').map do |a|
        a.to_s
         .tr('?', ' ')
         .tr("ْ", "ۡ") # replace U+0652 ARABIC SUKUN with U+06E1 ARABIC SMALL HIGH DOTLESS HEAD OF KHAH
         .html_safe
      end
    end

    #words_mapping.each do |k, words|
    #  verse = Verse.find_by(verse_key: k)
    #  verse.text_uthmani_tajweed = words.join(' ')
    #  verse.save
    #end

    1.upto(604) do |page|
      words = MushafWord.includes(:word).where(page_number: page, mushaf_id: mushaf.id).order('position_in_page ASC')
      pos = 0
      words.each do |w|
        word = MushafWord.new(w.attributes.except('id'))
        word.mushaf_id = tajweed_mushaf.id
        word.text = words_mapping[w.word.verse_key][pos].html_safe

        w.word.text_uthmani_tajweed = words_mapping[w.word.verse_key][pos].html_safe
        w.word.save

        word.save
        if w.word.ayah_mark?
          pos = 0
        else
          pos += 1
        end
      end
    end
  end

  task generate_diff_pages: :environment do
    def styles(page)
      "<style>
 @font-face {
  font-family: 'v4-p#{page}';
  src: url('../fonts/v4/woff2/QCF4#{page.to_s.rjust(3, '0')}-Regular.woff2');
 }

@font-face {
  font-family: 'v4-color-p#{page}';
  src: url('../fonts/v4-color/QCF4#{page.to_s.rjust(3, '0')}_Color-Regular.woff2'),
url('../fonts/v4/ttf/QCF4#{page.to_s.rjust(3, '0')}-Regular.ttf') format('truetype');
}

.v4-p#{page} .char{font-size: 40px;font-family: 'v4-p#{page}'; direction: rtl;}
.v4-color-p#{page} .char{font-size: 40px;font-family: 'v4-color-p#{page}'; direction: rtl;}

@font-palette-values --Light {
  font-family: 'v4-color-p#{page}';
    base-palette: 0;
    override-colors:
    0 black,
    1 red,
    2 orange,
    3 pink,
    18 #2C82C9;
}

@font-palette-values --Dark {
    font-family: 'v4-color-p#{page}';
    base-palette: 1;
    override-colors:
0 white,
1 #1BA39C,
2 #6D4B11,
3 #9E3E25,
4 #FC575E,
5 #FADAA3,
6 #8199A3,
18 #2C82C9;
}

@font-palette-values --Sepia {
  font-family: 'v4-color-p#{page}';
    base-palette: 2;
    override-colors:
0 black,
1 #E6567A,
2 #025159,
3 #3D8EB9,
4 #E75926,
5 #92F22A,
6 #FF770B,
7 #8A2D3C,
18 #2C82C9;
}
</style>"
    end
    def jquery
      "<script src='https://code.jquery.com/jquery-3.6.0.min.js'></script>"
    end

    data = JSON.parse(File.read("../community-data/uthmani_tajweed.json"))
    mushaf = Mushaf.find(5) #qpc hafs
    mushaf_v2 = Mushaf.find(1) #v2

    words_mapping = { }
    data.each do |key, text|
      words_mapping[key] = text.gsub(/"/, '').split(' ').map do |a|
        a.to_s
         .tr(" ۩", "۩")
        .tr('?', ' ')
        .tr("ْ", "ۡ") # replace U+0652 ARABIC SUKUN with U+06E1 ARABIC SMALL HIGH DOTLESS HEAD OF KHAH
        .html_safe
      end
    end

    def generate(page, mushaf, mushaf_v2, words_mapping)
      puts page
      words = MushafWord.includes(:word).where(page_number: page, mushaf_id: mushaf.id).order('position_in_page ASC')
      compare_words = words.dup
      v2_words = MushafWord.includes(:word).where(page_number: page, mushaf_id: mushaf_v2.id).order('position_in_page ASC')
      pos = 0
      compare_words.each do |w|
        if w.word.ayah_mark?
          w.text
        elsif words_mapping[w.word.verse_key][pos]
          w.text = words_mapping[w.word.verse_key][pos].html_safe
        else
          w.text = '?'
        end

        if w.word.ayah_mark?
          pos = 0
        else
          pos += 1
        end
      end

      File.open "../community-data/diff-preview/tajweed-words/hafs-pages/#{page}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<link href='../shared/styles.css' rel='stylesheet'/>"

        f.puts jquery

        f.puts "<div id=actions--right>
        <strong>Navigate</strong>
         <a href='#' class='btn btn-sm btn-success' id=toggle-table>Toggle table</a>
        <a class='btn btn-sm btn-success' href='#{page + 1}.html'>Next</a>
     <a class='btn btn-sm btn-success minus' href='#{page - 1}.html'>Previous</a>
   <strong class=my-2>Color theme</strong>
<a href='#' class='btn btn-primary btn-sm clr-theme'>Default</a>
<a href='#' class='btn btn-info btn-sm clr-theme' data-theme=light>Light</a>
<a href='#' class='btn btn-info btn-sm clr-theme' data-theme=dark>Dark</a>
<a href='#' class='btn btn-info btn-sm clr-theme' data-theme=sepia>Sepia</a>
<strong class=my-2>BG theme</strong>
<a href='#' class='btn btn-primary btn-sm bg-theme'>Default</a>
<a href='#' class='btn btn-info btn-sm bg-theme' data-theme=light>Light</a>
<a href='#' class='btn btn-info btn-sm bg-theme' data-theme=dark>Dark</a>
<a href='#' class='btn btn-info btn-sm bg-theme' data-theme=sepia>Sepia</a>
</div>"
        f.puts "<div class=container><div class=row><div class=c-12>"
        f.puts "<h2>Page #{page} <a class='btn btn-sm btn-success' href='#{page + 1}.html'>Next</a> <a class='btn btn-sm btn-success minus' href='#{page - 1}.html'>Previous</a> </h2>"

        f.puts "<table class='table'>
          <thead><tr class='sticky'>
                <th>Word</th>
               <th>V4 Color</th>
               <th>Hafs</th>
               <th>Hafs Color</th>
              </tr></thead><tbody>"
        words.each_with_index do |word, i|
          f.puts "<tr>"
          f.puts "<td>#{word.word.location}</td>"
          f.puts "<td class='v4-color-p#{word.page_number}'><span class=char>#{v2_words[i].text}</span></td>"
          f.puts "<td class='qpc-hafs'><span class=char>#{word.text}</span></td>"
          f.puts "<td class='qpc-hafs'><span class=char>#{compare_words[i]&.text}</span></td>"

          f.puts "</tr>"
        end

        f.puts "</tbody></table>"
        f.puts "</div></div>"

        f.puts "<div class=m2><h3>V4 vs v4 color</h3>"

        f.puts ApplicationController.render(
          partial: 'mushaf_layouts/show',
          locals: {
            mushaf_name: 'QPC',
            params: {},
            word_class: "qpc-hafs",
            page_number: page,
            words: words,
            mushaf: mushaf,
            compare_words: compare_words,
            compare_mushaf_name: "Hafs Color",
            compare_mushaf_class: "qpc-hafs"
          })
        f.puts "</div>"

        f.puts styles(page)
        f.puts "<script src='../shared/script.js'></script>"
        f.puts "</div></body></html>"
      end
    end

    1.upto(604) do |page|
      generate(page, mushaf, mushaf_v2, words_mapping)
    end
  end

  task parse_wbw_tajweed: :environment do
    data = JSON.parse(File.read("../community-data/uthmani_tajweed.json"))
    data_words = JSON.parse(File.read("../community-data/uthmani_tajweed_words.json"))

    miss_match_ayahs = []
    diff = []
    data.each do |key, text|
      words = Word.where(verse_key: key).order("position ASC")

      if data_words[key].size != words.size
        diff << key
      end

      if text.split(" ").size != words.size
        miss_match_ayahs << key
      end
    end
  end

  task fix_uthmani_tajweed_rule: :environment do
    # NOTE: eventually went with js based solution.
    # Run following in browser console and i'll log the fixed text
    # copy the text and save as json file
=begin
    const createRule = (textContent, className) => Object.assign(document.createElement("rule"), {textContent, className})

    function fixAyaText(e) {
      if (!e) return "";
      var div = document.createElement("div");
      // remove space after hizb sign
      div.innerHTML = e.replace("۞ ", "۞");

      div.querySelectorAll("tajweed").forEach((function (span) {
        let text = span.textContent;
        let t = span.className;

        if (text.includes(" ")) {
          let parts = text.split(" ");
        let newRules = [
          createRule(parts[0], t), ' ',createRule(parts[1], t)
        ];

        span.replaceWith(...newRules)
        }

        if ("madda_obligatory" === t) {
          var n = span.outerHTML,
          o = div.innerHTML.indexOf(n),
          c = div.innerHTML.substring(o + n.length, o + n.length + 1);
        span.className = " " === c ? "madda_obligatory_monfasel" : "madda_obligatory_mottasel"
        }
        }))

        alefMaksora = 'ٰ'

return div.innerHTML
        .replace(/َٲ/g, `<rule class="custom-alef-maksora">${alefMaksora}</rule>`)
        .replace(/و۟/g, "وْ")
        .replace(/ا۟/g, "اْ")
        .replace(/<span class="?end"?>|<\/span>/g, "")
        .replace(/<\/tajweed>/g, "</rule>")
        .replace(/<tajweed/g, "<rule")
        .replace(/<rule class=/g, "<rule?class=") // remove space

        /*return div.innerHTML
        .replace(/َٲ/g, '<rule class="custom-alef-maksora">ا</rule>')
        .replace(/ٲ/g, '<rule class="custom-alef-maksora">ا</rule>')
        .replace(/و۟/g, "وْ")
        .replace(/ا۟/g, "اْ")
        .replace(/<span class="end">.*?<\/span>/g, "")
        .replace(/<\/tajweed>/g, "</rule>")
        .replace(/<tajweed/g, "<rule")
        .replace(/<rule class=/g, "<rule?class=")*/
        }

        results = {}
        words = {}

        fetch("https://api.quran.com/api/v4/quran/verses/text_uthmani_tajweed").then(e => e.json()).then(json => {
          json.verses.forEach(v => {
            console.log(v.verse_key)
           text = fixAyaText(v.text_uthmani_tajweed);
           results[v.verse_key] = text;
           words[v.verse_key] = text.split(" ")
        })
        })

    console.log(JSON.stringify(results))
    console.log(JSON.stringify(words))

=end
  end

  task parse_alquran: :environment do
    require 'open-uri'

    Verse.find_each do |v|
      next if v.text_uthmani_tajweed.present?

      url = "http://api.alquran.cloud/ayah/#{v.verse_key}/quran-tajweed"
      text = JSON.parse(URI.open(url).read)['data']['text']

      parser = Utils::TajweedText.new text
      tajweed = parser.parse_buckwalter_tajweed(text)

      v.update_column :text_uthmani_tajweed, tajweed
    end
  end
end
