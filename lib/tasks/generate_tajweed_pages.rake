namespace :generate_tajweed_pages do
  task fix_dagger_alif: :environment do
    Word.where("text_uthmani_tajweed like ?", "%ٲ%").each do |w|
      w.text_uthmani_tajweed = w.text_uthmani_tajweed.gsub("ٲ", "ٰ")
      w.save

      MushafWord.where(mushaf_id: 16, word_id: w.id).update(text: w.text_uthmani_tajweed)
    end
  end

  task generate: :environment do
    def fix
      Dir["../community-data/diff-preview/tajweed-words/svg/common/*.svg"].each do |p|
        num = p[/\d+/].to_i
        FileUtils.mv(p, "/Volumes/Development/qdc/community-data/diff-preview/tajweed-words/svg/common/#{num}.svg")
      end
    end

    def tajweed_page(page)
      "<div class='my-5 pt-5'>
    <div style='display: flex;justify-content: space-around;' class='mushaf-wrapper'>
        <div class='mushaf-layout'>
            <div class='mushaf'>
                <div class='page-wrapper'>
                    <div class='page'>
                      <img src='../imgs/#{page}.png' />
                    </div>
                </div>
            </div>
        </div>

        <div class='mushaf-layout'>
          <div id='placeholder'></div>
        </div>
    </div>
</div>"
    end

    def styles(page)
      "<style>
 @font-face {
  font-family: 'v4-p#{page}';
  src: url('../fonts/v4/woff2/QCF4#{page.to_s.rjust(3, '0')}-Regular.woff2');
 }

@font-face {
  font-family: 'v4-color-p#{page}';
  src: url('../fonts/v4-color/QCF4#{page.to_s.rjust(3, '0')}_Color-Regular.woff2');
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

    def word_image(word)
      if word.word?
        url = "https://static.qurancdn.com/images/w/qa-color/#{word.word.location.gsub(':', '/')}.png"
      else
        url = "https://static.qurancdn.com/images/w/common/#{word.word.verse_key.split(':')[1]}.png"
      end

      "<span data-word-id='#{word.word_id}'><img src=#{url} /></span>"
    end

    def svg_path(word)
      if word.word?
        "../svg/rq/#{word.word.location.gsub(':', '/')}.svg"
      else
        "../svg/common/#{word.word.verse_key.split(':')[1]}.svg"
      end
    end

    def word_svg(word)
      "<span data-word-id='#{word.word_id}'><img src=#{svg_path(word)} /></span>"
    end

    def jquery
      "<script src='https://code.jquery.com/jquery-3.6.0.min.js'></script>"
    end

    class MushafWord < QuranApiRecord
      def image_url
        if text.include?('svg')
          text
        else
          "#{CDN_HOST}/images/#{text}"
        end
      end
    end

    mushaf = Mushaf.find(1) #v2
    mushaf_tajweed_imgs = Mushaf.find(10) #QA tajweed

    1.upto(604) do |page|
      puts page
      words = MushafWord.includes(:word).where(page_number: page, mushaf_id: mushaf.id).order('position_in_page ASC')
      compare_words = words

      File.open "../community-data/diff-preview/tajweed-words/pages/#{page}.html", "wb" do |f|
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
               <th>Img</th>
               <th>Svg</th>
               <th>V4 Color</th>
               <th>V4</th>
              </tr></thead><tbody>"
        words.each do |word|
          f.puts "<tr>"
          f.puts "<td>#{word.word.location}</td>"
          f.puts "<td class=mushaf-img>#{word_image word}</td>"
          f.puts "<td class=mushaf-svg>#{word_svg word}</td>"
          f.puts "<td class='v4-color-p#{word.page_number}'><span class=char>#{word.text}</span></td>"
          f.puts "<td class='v4-p#{word.page_number}'><span class=char>#{word.text}</span></td>"
          f.puts "</tr>"
        end

        f.puts "</tbody></table>"
        f.puts "</div></div>"

        f.puts "<div class=m2><h3>V4 vs v4 color</h3>"
        f.puts ApplicationController.render(
          partial: 'mushaf_layouts/show',
          locals: {
            mushaf_name: 'V4',
            params: {},
            word_class: "mushaf-v4 v4-p#{page}",
            page_number: page,
            words: words,
            mushaf: mushaf,
            compare_words: compare_words,
            compare_mushaf_name: 'V4 tajweed',
            compare_mushaf_class: "mushaf-v4-color v4-color-p#{page}"
          })
        f.puts "</div>"

        tajweed_img_words = MushafWord.includes(:word).where(page_number: page, mushaf_id: mushaf_tajweed_imgs.id).order('position_in_page ASC')
        tajweed_svg_words = MushafWord.includes(:word).where(page_number: page, mushaf_id: mushaf_tajweed_imgs.id).order('position_in_page ASC')

        tajweed_svg_words.each do |w|
          w.text = svg_path(w)
        end

        f.puts "<div class=m2><h3>Img vs Svg</h3>"
        f.puts ApplicationController.render(
          partial: 'mushaf_layouts/show',
          locals: {
            mushaf_name: 'Tajweed Image',
            word_class: 'mushaf-img',
            params: {},
            page_number: page,
            words: tajweed_img_words,
            mushaf: mushaf_tajweed_imgs,
            compare_words: tajweed_svg_words,
            compare_mushaf_name: 'Tajweed Svg',
            compare_mushaf_class: 'mushaf-svg',
            show_header: false
          })
        f.puts "</div>"

        f.puts tajweed_page(page)

        f.puts styles(page)
        f.puts "<script src='../shared/script.js'></script>"
        f.puts "</div></body></html>"
      end
    end
  end
end