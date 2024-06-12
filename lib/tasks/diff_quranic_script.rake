namespace :diff_quranic_script do
  def diff_styles
    "<style>
.diff{overflow:auto;}
.diff ul{background:#fff;overflow:auto; direction:rtl;}
.diff del, .diff ins{display:block;text-decoration:none;}
.diff li.ins{background:#dfd; color:#080}
.diff li.del{background:#fee; color:#b00}
.diff li{background:#ffc; display:inline-block; margin-right: 15px}
.diff del, .diff ins, .diff span{white-space:pre-wrap;}
.diff del strong{font-weight:normal;background:#fcc;}
.diff ins strong{font-weight:normal;background:#9f9;}
.ml-2{margin-left: 5px}
.sticky{position: sticky;top:5px;background: #fff;z-index:10;}
.ltr{direction: ltr;}
.rtl{direction: rtl}
td{cursor: pointer;}
</style>"
  end

  def diff_js
    "<script>
     document.querySelector('button').addEventListener('click', ()=> {
       document.querySelectorAll('tbody tr').forEach(tr => {
      if(!tr.querySelector('ul strong')) tr.classList.toggle('d-none')
    })
    })
   addEventListener('click', e => {
      const node = e.target;
      navigator.clipboard.writeText(node.textContent);
      console.log(node.textContent, ' copied to clipboard')

    }, false);
</script>
"
  end

  def jquery
    "<script src='https://code.jquery.com/jquery-3.6.0.min.js'></script>"
  end

  def font_size_js
    "<script>
    const ayahs = $('.page .ayah');
    const words = $('.page .ayah .char');

    ayahs.on('mouseover', (event) => {
      const ayah = event.currentTarget.dataset.ayah;
      $(`[data-ayah=${ayah}]`).addClass('highlight')
    });

    ayahs.on('mouseout', (event) => {
      const ayah = event.currentTarget.dataset.ayah;
      $(`[data-ayah=${ayah}]`).removeClass('highlight')
    });

    words.on('mouseover', (event) => {
      const wordId = event.currentTarget.dataset.wordId;
      $(`[data-word-id=${wordId}]`).addClass('highlight')
    });

    words.on('mouseout', (event) => {
      const wordId = event.currentTarget.dataset.wordId;
      $(`[data-word-id=${wordId}]`).removeClass('highlight')
    });

    document.querySelectorAll('.font-size-slider').forEach((slider) => {
      slider.oninput = (event) => {
        const fontSize = event.target.value;
        const wrapper = $(event.target).closest('.mushaf-layout');

        wrapper.find('.char').css('font-size', `${fontSize}px`);
        wrapper.find('#size').html(fontSize)
      }
    });
</script>"
  end

  task diff_indopak_v95_em_spacers: :environment do
    v95 = "Indopakv9.5/Indopak.v.9.5.WitSpacers-Hanafi-Words+Ayah-83665.txt"
    mushaf = Mushaf.find(6)
    word_text = {}
    v95_words = File.read(v95).lines
    index = 0
    REGEXP_INDOPAK_WAQF_MARKS = Regexp.new(["ۛ", "ٚ", "ؔ", "ؕ", "ۥ", "ۚ", "۪", "۠", "ۙ", "ؗ", "۫", "ۘ", "ۗ", "۬", "ۙ", "۬", "ۦ"].join('|'))

    Chapter.order('id ASC').each do |chapter|
      File.open "../community-data/diff-preview/indopak9.5-em-dash/surah/#{chapter.id}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<link href='../fonts/style.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<style>@font-face {
  font-family: 'QuranWBv95';
  src: url('../fonts/indopak-nastaleeq-waqf-lazim-9.5.woff2');
  }
 @font-face {
          font-family: 'QuranWBv94';
          src: url('../fonts/indopak-nastaleeq-waqf-lazim-9.4.woff2');
        }
  table .v95{font-size: 40px;font-family: 'QuranWBv95'; direction: rtl;}
  table .v94{font-size: 40px;font-family: 'QuranWBv94'; direction: rtl;}
</style>
"
        f.puts diff_styles
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<table class='table table-bordered rtl'><thead>
<tr class='sticky'>
<th>Key</th>
<th>Current</th>
<th>New 9.5(EmDashed)</th>
<th title='diff'>Diff<button id=toggle class='btn btn-sm btn-success'>Toggle diff</button></th>
</tr></thead><tbody class=rtl>"
        chapter.verses.eager_load(:words).order('verse_index ASC, words.position').each do |verse|
          puts verse.verse_key

          words = verse.words
          words.each do |word|
            current = word.text_indopak_nastaleeq
            v95 = v95_words[index].to_s.strip
            index += 1
            word_text[word.location] = v95

            diff = Diffy::Diff.new(current, v95.gsub("—", '')).to_s(:html).html_safe

            f.puts "<tr class=rtl>"
            f.puts "<td>#{word.location}</td>"
            f.puts "<td class='v94 rtl'>#{current}</td>"
            f.puts "<td class='v95 rtl'>#{v95}</td>"
            f.puts "<td class='v95 rtl'>#{diff}</td>"
            f.puts "</tr>"
          end
        end

        f.puts "</tbody></table>"
        f.puts diff_js
        f.puts "</body></html>"
      end
    end

    1.upto(mushaf.pages_count) do |page|
      puts page
      words = MushafWord.includes(:word).where(page_number: page, mushaf_id: mushaf.id).order('position_in_page ASC')
      compare_words = []

      words.each do |word|
        compare_word = MushafWord.new(word.attributes)
        compare_word.text = word_text[word.word.location]
        compare_words << compare_word
      end

      File.open "../community-data/diff-preview/indopak9.5-em-dash/pages/#{page}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<link href='../fonts/style.css' rel='stylesheet'  crossorigin='anonymous'>"

        f.puts "<style>
@font-face {
  font-family: 'QuranWBWv95';
  src: url('../fonts/indopak-nastaleeq-waqf-lazim-9.5.woff2');
  }
 @font-face {
          font-family: 'QuranWBWv94';
          src: url('../fonts/indopak-nastaleeq-waqf-lazim-9.4.woff2');
        }
  table .v95, .compare .char{font-size: 29px;font-family: 'QuranWBWv95' !important; direction: rtl;}
  table .v94, .mushaf .char{font-size: 29px;font-family: 'QuranWBWv94'; direction: rtl;}</style>"

        f.puts jquery

        f.puts "<div class=container><div class=row><div class=c-12>"
        f.puts "<h2>Page #{page} <a class='btn btn-sm btn-success' href='#{page + 1}.html'>Next</a> <a class='btn btn-sm btn-success minus' href='#{page - 1}.html'>Previous</a> </h2>"

        f.puts "<table class='table rtl'>
          <thead><tr class='sticky'>
                <th>WordId</th>
               <th>Current</th>
               <th>9.5(with em-dashed)</th>
              </tr></thead><tbody>"
        words.each_with_index do |word, i|
          f.puts "<tr>"
          f.puts "<td>#{word.word.location}</td>"
          f.puts "<td class='v94 rtl'>#{word.text}</td>"
          f.puts "<td class='v95 rtl'>#{compare_words[i].text}</td>"
          f.puts "</tr>"
        end
        f.puts "</tbody></table>"
        f.puts "</div></div>"

        f.puts "<div class=rtl>"
        f.puts ApplicationController.render(partial: 'mushaf_layouts/show', locals: { params: {}, page_number: page, words: words, mushaf: mushaf, compare_words: compare_words })
        f.puts "</div>"
        f.puts font_size_js

        f.puts "</div></body></html>"
      end

      File.open "../community-data/diff-preview/indopak9.5-em-dash/pages-no-em-dash/#{page}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet' crossorigin='anonymous'>"
        f.puts "<link href='../fonts/style.css' rel='stylesheet'>"

        f.puts "<style>
@font-face {
  font-family: 'QuranWBWv95';
  src: url('../fonts/indopak-nastaleeq-waqf-lazim-9.5.woff2');
  }
 @font-face {
          font-family: 'QuranWBWv94';
          src: url('../fonts/indopak-nastaleeq-waqf-lazim-9.4.woff2');
        }
  table .v95, .compare .char{font-size: 29px;font-family: 'QuranWBWv95' !important; direction: rtl;}
  table .v94, .mushaf .char{font-size: 29px;font-family: 'QuranWBWv94'; direction: rtl;}</style>"
        f.puts jquery

        f.puts "<div class=container><div class=row><div class=c-12>"
        f.puts "<h2>Page #{page} <a class='btn btn-sm btn-success' href='#{page + 1}.html'>Next</a> <a class='btn btn-sm btn-success minus' href='#{page - 1}.html'>Previous</a> </h2>"

        f.puts "<table class='table rtl'>
          <thead><tr class='sticky'>
                <th>WordId</th>
               <th>Current</th>
               <th>9.5(with em-dashed)</th>
              </tr></thead><tbody>"
        words.each_with_index do |word, i|
          f.puts "<tr>"
          f.puts "<td>#{word.word.location}</td>"
          f.puts "<td class='v94 rtl'>#{word.text}</td>"
          f.puts "<td class='v95 rtl'>#{compare_words[i].text}</td>"
          f.puts "</tr>"
        end
        f.puts "</tbody></table>"
        f.puts "</div></div>"

        f.puts "<div class=rtl>"

        compare_words = compare_words.map do |w|
          w.text = w.text.gsub("—", '') unless w.text.match?(REGEXP_INDOPAK_WAQF_MARKS)
          w
        end

        f.puts ApplicationController.render(partial: 'mushaf_layouts/show', locals: { params: {}, page_number: page, words: words, mushaf: mushaf, compare_words: compare_words })
        f.puts "</div>"
        f.puts font_size_js

        f.puts "</div></body></html>"
      end
    end

  end

  task diff_maldavian: :environment do
    lines_alt = File.readlines("data/alt_dv.divehi.txt")
    lines_master = File.readlines("data/master_dv.divehi.txt")

    File.open "../community-data/diff-preview/divehi/alt_diff.html", "wb" do |f|
      f.puts "<html><body>"

      f.puts diff_styles
      f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
      f.puts "<table class='table table-bordered'><thead>
<tr class='sticky'>
<th>Ayah</th>
<th>Master</th>
<th>ALt</th>
<th title='diff'>Diff<button id=toggle class='btn btn-sm btn-success'>Toggle diff</button></th>
</tr></thead><tbody>"

      lines_master.each_with_index do |master, index|
        alt = lines_alt[index].sub(/\d+\|\d+\|/, '').strip
        master = master.sub(/\d+\|\d+\|/, '').strip

        diff = Diffy::Diff.new(master, alt).to_s(:html).html_safe
        key = Utils::Quran.get_ayah_key_from_id(index + 1)

        f.puts "<tr>"
        f.puts "<td>#{key}</td>"
        f.puts "<td>#{master}</td>"
        f.puts "<td class='v95'>#{alt}</td>"
        f.puts "<td class=v95>#{diff}</td>"
        f.puts "</tr>"
      end

      f.puts "</tbody></table>"
      f.puts diff_js
      f.puts "</body></html>"
    end

    resource = ResourceContent.find(86)
    File.open "../community-data/diff-preview/divehi/diff_with_current_and_master.html", "wb" do |f|
      f.puts "<html><body>"

      f.puts diff_styles
      f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
      f.puts "<table class='table table-bordered'><thead>
<tr class='sticky'>
<th>Ayah</th>
<th>Current</th>
<th>New</th>
<th class=ltr title='diff'>Diff<button id=toggle class='btn btn-sm btn-success'>Toggle diff</button></th>
</tr></thead><tbody>"

      lines_master.each_with_index do |alt, index|
        alt = alt.sub(/\d+\|\d+\|/, '').strip
        key = Utils::Quran.get_ayah_key_from_id(index + 1)
        current = Translation.where(resource_content_id: resource.id, verse_id: index + 1).first.text.strip
        diff = Diffy::Diff.new(current, alt).to_s(:html).html_safe

        f.puts "<tr>"
        f.puts "<td>#{key}</td>"
        f.puts "<td>#{current}</td>"
        f.puts "<td class='v95'>#{alt}</td>"
        f.puts "<td class=v95>#{diff}</td>"
        f.puts "</tr>"
      end

      f.puts "</tbody></table>"
      f.puts diff_js
      f.puts "</body></html>"
    end
  end

  task diff_font_size: :environment do
    def report_size(version, type)
      total_optimization = 0
      File.open "../community-data/diff-preview/size/#{version}-#{type}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<h2>#{version} #{type} font optimization result</h2>"
        f.puts "<table class='table table-bordered'><tr> <th>File</th> <th>Current size</th> <th>new size</th><th>Diff</th></tr>"

        files = Dir["../community-data/diff-preview/#{version}/fonts/optimized/#{type}/*.#{type}"].sort_by do |a|
          name = File.basename(a)
          name[/\d+/].to_i
        end

        files.each do |file|
          name = File.basename(file)
          current_file = "../community-data/diff-preview/#{version}/fonts/#{version}/#{type}/#{name}"
          size = File.size(file)
          current_size = File.size(current_file)

          diff = current_size - size
          total_optimization += diff
          f.puts "<tr><td>#{name}</td> <td>#{current_size.to_s(:human_size)}</td> <td>#{size.to_s(:human_size)}</td> <td>#{diff.to_s(:human_size)}</td></tr>"
        end

        f.puts "</table>"
        f.puts "<h2>Total optimization #{total_optimization.to_s(:human_size)}</h2>"
        f.puts "</body></html>"
      end
    end

    report_size 'v1', 'ttf'
    report_size 'v1', 'woff'
    report_size 'v1', 'woff2'

    report_size 'v2', 'ttf'
    report_size 'v2', 'woff'
    report_size 'v2', 'woff2'
  end

  task rename_fonts: :environment do
    Dir["../community-data/diff-preview/v2/fonts/optimized/ttf/*.ttf"].each do |file|
      new_name = file.sub(/QCF2[0]*/, 'p')
      FileUtils.mv(file, new_name) if new_name != file
    end

    # v4
    Dir["app/assets/fonts/quran_fonts/v4-tajweed/ttf/*.ttf"].map do |file|
      page = file.split('/').last.sub(/QCF4/,'').gsub('_COLOR-Regular.ttf', '')[/\d+/].to_i
      new_name = "app/assets/fonts/quran_fonts/v4-tajweed/ttf/p#{page}.ttf"
      FileUtils.mv(file, new_name) if new_name != file
    end

    Dir["app/assets/fonts/quran_fonts/v4-tajweed/woff/*.woff"].map do |file|
      page = file.split('/').last.sub(/QCF4/,'').gsub('_COLOR-Regular.woff', '')[/\d+/].to_i
      new_name = "app/assets/fonts/quran_fonts/v4-tajweed/woff/p#{page}.woff"
      FileUtils.mv(file, new_name) if new_name != file
    end

    Dir["app/assets/fonts/quran_fonts/v4-tajweed/woff2/*.woff2"].map do |file|
      page = file.split('/').last.sub(/QCF4/,'').gsub('_COLOR-Regular.woff2', '')[/\d+/].to_i
      new_name = "app/assets/fonts/quran_fonts/v4-tajweed/woff2/p#{page}.woff2"
      FileUtils.mv(file, new_name) if new_name != file
    end
  end

  task diff_v1_font: :environment do
    def font_faces_v1(page)
      "
        @font-face {
        font-family: 'p#{page}';
        src: url('fonts/v2/woff2/p#{page}.woff2');
       }
      @font-face {
        font-family: 'new-p#{page}';
        src: url('fonts/optimized/woff2/p#{page}.woff2');
       }
       .p#{page} .char{font-family: p#{page}; font-size: 40px;}
       .new-p#{page} .char{font-family: new-p#{page}; font-size: 40px;}
       "
    end

    def word_image(word)
      if word.word?
        url = "https://static.qurancdn.com/images/w/qa-color/#{word.word.location.gsub(':', '/')}.png"
      else
        url = "https://static.qurancdn.com/images/w/common/#{word.word.verse_key.split(':')[1]}.png"
      end
      "<img src=#{url} />"
    end

    1.upto(604) do |page|
      puts page
      words = MushafWord.includes(:word).where(page_number: page, mushaf_id: 1).order('position_in_page ASC')

      File.open "../community-data/diff-preview/v2/#{page}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<style>#{font_faces_v1(page)}</style>"
        f.puts jquery

        f.puts "<div class=row><div class=c-12>"
        f.puts "<h2>Page #{page}   <a class='btn btn-sm btn-success' href='#{page + 1}.html'>Next</a> <a class='btn btn-sm btn-success minus' href='#{page - 1}.html'>Previous</a> </h2>"

        f.puts "<table class='table'>
          <thead><tr class='sticky'>
                <th>WordId</th>
               <th>img</th>
               <th>Current</th>
               <th>New</th></tr></thead><tbody>"

        words.each do |word|
          f.puts "<tr>"
          f.puts "<td>#{word.word.location}</td>"
          f.puts "<td>#{word_image word}</td>"
          f.puts "<td class='p#{word.page_number}'>
      <span class=char>#{word.text}</span>
  </td>"
          f.puts "<td class='new-p#{word.page_number}'><span class=char>#{word.text}</span></td>"
          f.puts "</tr>"
        end

        f.puts "</tbody></table>"
        f.puts "</div></div>"

        f.puts ApplicationController.render(partial: 'mushaf_layouts/show', locals: { page_number: page, words: words })
        f.puts font_size_js

        f.puts "</body></html>"
      end
    end
  end

  task generate_v2: :environment do
    def font_faces_v2(chapter)
      pages = chapter.verses.pluck(:v2_page).uniq
      pages.map do |page|
        "
        @font-face {
        font-family: 'p#{page}';
        src: url('fonts/v2/woff2/p#{page}.woff2');
       }
      @font-face {
        font-family: 'op#{page}';
        src: url('fonts/optimized/woff2/p#{page}.woff2');
       }

       .p#{page}{font-family: p#{page};font-size: 40px;}
       .op#{page}{font-family: op#{page};font-size: 40px;}
       "
      end.join('')
    end

    Chapter.order('id ASC').each do |chapter|
      File.open "../community-data/diff-preview/v2/#{chapter.id}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<table class='table'>
          <thead><tr class='sticky'><th>WordId</th>
               <th>Current</th><th>New</th></tr></thead><tbody>"
        f.puts "<style>#{font_faces(chapter)}</style>"
        chapter.verses.eager_load(:words).order('verse_index ASC, words.position').each do |verse|
          puts verse.verse_key

          words = verse.words
          words.each do |word|
            f.puts "<tr>"
            f.puts "<td>#{word.location}</td>"
            f.puts "<td class='v2 p#{word.v2_page}'>#{word.code_v2}</td>"
            f.puts "<td class='new p#{word.v2_page}'>#{word.code_v2}</td>"
            f.puts "</tr>"
          end
        end

        f.puts "</tbody></table>"
        f.puts "</body></html>"
      end
    end
  end

  task generate_surah_name_table: :environment do
    def hd_css_class(chapter)
      if chapter.id <= 59
        'HDName1'
      else
        'HDName2'
      end
    end

    def hd_code(chapter)
      codes = %w(1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u B C D E F G H I J K L M N O P Q R S T U V W X Y Z 1 2 3 4 5 6 7 8 9)
      codes[chapter.id - 1]
    end

    File.open "data/surah name/table.html", "wb" do |f|
      f.puts "<html><body>"
      f.puts "<style>
@font-face {
  font-family: 'UthmanicHafs1Ver18';
  src: url('./fonts/UthmanicHafs1Ver18.ttf');
 }
@font-face {
  font-family: 'v1suraname';
  src: url('./fonts/v1/sura_names.woff');
 }
@font-face {
  font-family: 'HDName1';
  src: url('./fonts/v2HD/QuranSurah1.ttf');
 }
@font-face {
  font-family: 'HDName2';
  src: url('./fonts/v2HD/QuranSurah2.ttf');
 }
@font-face {
  font-family: 'v2suraname';
  src: url('./fonts/v2/sura_names.woff');
 }
@font-face{
  font-family: 'qpcv2';
  src: url('./fonts/QWBWSurah/sura_names.woff');
}
.antialiased{
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

table tr .qpc{font-size: 40px;font-family: 'UthmanicHafs1Ver18'; direction: rtl;}
table tr .v1{font-size: 40px;font-family: 'v1suraname'; direction: rtl;}
table tr .v2{font-size: 70px;font-family: 'v2suraname'; direction: rtl;}
table tr .HDName1{font-size: 70px;font-family: 'HDName1';}
table tr .HDName2{font-size: 70px;font-family: 'HDName2';}
table tr .qpcv2{font-size: 40px; font-family: qpcv2;}
</style>"
      f.puts diff_styles
      f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
      f.puts "<table class='table table-bordered'><thead>
          <tr class='sticky'>
              <th>Surah</th>
              <th class=ltr>Hafs</th>
              <th class=ltr>V1</th>
              <th class=ltr>V2</th>
              <th>QPC v2</th>
              <th>HD v2 <button id=toggle class='btn btn-sm btn-success'>Toggle Antialiased</button></th>
              </tr></thead><tbody>"
      Chapter.order('ID asc').each do |chapter|
        code = chapter.id.to_s.rjust(3, '0')
        f.puts "<tr>"
        f.puts "<td>#{chapter.id}</td>"
        f.puts "<td class='qpc ltr'>
          #{chapter.name_arabic}</td>"
        f.puts "<td class='v1 ltr'><span>#{code}</span><span class=s>surah</span></td>"
        f.puts "<td class='v2 ltr'><span>#{code}</span><span class=s>surah</span></td>"
        f.puts "<td class='qpcv2 ltr'>#{code}</td>"
        f.puts "<td><span class='#{hd_css_class(chapter)}'>#{hd_code(chapter)}</span><span class='s HDName1'>0</span></td>"

        f.puts "</tr>"
      end
      f.puts "</tbody></table>"
      f.puts "<script>
     document.querySelector('button').addEventListener('click', ()=> {
       document.querySelectorAll('tbody td').forEach(td => {
      td.classList.toggle('antialiased')
    })
    })
</script>"
      f.puts "</body></html>"
    end
  end

  task diff_qpc_and_indopak_v95_script: :environment do
    v95 = "../community-data/diff-preview/indopak-9.4-vs-9.5/Indopak.v.9.5.WithPMSpacers-Hanafi-Words+Ayah-83665.txt"
    v94 = "../community-data/diff-preview/indopak-9.4-vs-9.5/Indopak.v.9.4.Hanafi-Words+Ayah-83665.txt"
    mushaf = Mushaf.find(6)

    v95_words = File.read(v95).lines
    v94_words = File.read(v94).lines

    ayah_text = {}
    word_text = {}
    index = 0

    Chapter.order('id ASC').each do |chapter|
      File.open "../community-data/diff-preview/indopak-9.4-vs-9.5/#{chapter.id}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<style>@font-face {
  font-family: 'QuranWBv95';
  src: url('fonts/indopak-nastaleeq-waqf-lazim-9.5.woff2');
  }
 @font-face {
          font-family: 'QuranWBv94';
          src: url('fonts/indopak-nastaleeq-waqf-lazim-9.4.woff2');
        }
  table .v95{font-size: 40px;font-family: 'QuranWBv95'; direction: rtl;}
  table .v94{font-size: 40px;font-family: 'QuranWBv94'; direction: rtl;}
</style>
"
        f.puts diff_styles
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<table class='table table-bordered'><thead>
<tr class='sticky'>
<th>Key</th>
<th>Current(9.4)</th>
<th>New 9.5</th>
<th class=ltr title='diff'>Diff<button id=toggle class='btn btn-sm btn-success'>Toggle diff</button></th>
</tr></thead><tbody>"
        chapter.verses.eager_load(:words).order('verse_index ASC, words.position').each do |verse|
          puts verse.verse_key
          v94_ayah = []
          v95_ayah = []

          words = verse.words
          words.each do |word|
            v94 = v94_words[index].to_s.strip.gsub("—", '')
            v95 = v95_words[index].to_s.strip.gsub("—", '')

            v94_text = v94
            v95_text = v95
            v94_ayah << v94
            v95_ayah << v95
            word_text[word.location] = v95_text

            index += 1

            diff = Diffy::Diff.new(v94_text, v95_text).to_s(:html).html_safe

            f.puts "<tr>"
            f.puts "<td>#{word.location}</td>"
            f.puts "<td class=v94>#{v94_text}</td>"
            f.puts "<td class='v95'>#{v95_text}</td>"
            f.puts "<td class=v95>#{diff}</td>"
            f.puts "</tr>"
          end

          ayah_text[verse.verse_key] = {
            v94: v94_ayah.join(' '),
            v95: v95_ayah.join(' ')
          }
        end

        f.puts "</tbody></table>"
        f.puts diff_js
        f.puts "</body></html>"
      end

      File.open "../community-data/diff-preview/indopak-9.4-vs-9.5/#{chapter.id}-ayah.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<style>@font-face {
  font-family: 'QuranWBv95';
  src: url('fonts/indopak-nastaleeq-waqf-lazim-9.5.woff2');
  }
 @font-face {
          font-family: 'QuranWBv94';
          src: url('fonts/indopak-nastaleeq-waqf-lazim-9.4.woff2');
        }
  table .v95{font-size: 40px;font-family: 'QuranWBv95'; direction: rtl;}
  table .v94{font-size: 40px;font-family: 'QuranWBv94'; direction: rtl;}
</style>
"
        f.puts diff_styles
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<table class='table table-bordered'><thead>
<tr class='sticky'>
<th>Key</th>
<th>Current(9.4)</th>
<th>New 9.5</th>
</tr></thead><tbody>"
        chapter.verses.eager_load(:words).order('verse_index ASC, words.position').each do |verse|

          f.puts "<tr>"
          f.puts "<td>#{verse.verse_key}</td>"
          f.puts "<td class=v94>#{ayah_text[verse.verse_key][:v94]}</td>"
          f.puts "<td class='v95'>#{ayah_text[verse.verse_key][:v95]}</td>"
          f.puts "</tr>"
        end

        f.puts "</tbody></table>"
        f.puts diff_js
        f.puts "</body></html>"
      end
    end

    1.upto(mushaf.pages_count) do |page|
      puts page
      words = MushafWord.includes(:word).where(page_number: page, mushaf_id: mushaf.id).order('position_in_page ASC')
      compare_words = []

      words.each do |word|
        compare_word = MushafWord.new(word.attributes)
        compare_word.text = word_text[word.word.location]
        compare_words << compare_word
      end

      File.open "../community-data/diff-preview/indopak-9.4-vs-9.5/pages/#{page}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"

        f.puts "<style>
@font-face {
  font-family: 'QuranWBWv95';
  src: url('../fonts/indopak-nastaleeq-waqf-lazim-9.5.woff2');
  }
 @font-face {
          font-family: 'QuranWBWv94';
          src: url('../fonts/indopak-nastaleeq-waqf-lazim-9.4.woff2');
        }
  table .v95, .compare .char{font-size: 40px;font-family: 'QuranWBWv95' !important; direction: rtl;}
  table .v94, .mushaf .char{font-size: 40px;font-family: 'QuranWBWv94'; direction: rtl;}</style>"

        f.puts jquery

        f.puts "<div class=container><div class=row><div class=c-12>"
        f.puts "<h2>Page #{page} <a class='btn btn-sm btn-success' href='#{page + 1}.html'>Next</a> <a class='btn btn-sm btn-success minus' href='#{page - 1}.html'>Previous</a> </h2>"

        f.puts "<table class='table'>
          <thead><tr class='sticky'>
                <th>WordId</th>
               <th>9.4</th>
               <th>9.5</th>
              </tr></thead><tbody>"
        words.each_with_index do |word, i|
          f.puts "<tr>"
          f.puts "<td>#{word.word.location}</td>"
          f.puts "<td class=v94>#{word.text}</td>"
          f.puts "<td class=v95>#{compare_words[i].text}</td>"
          f.puts "</tr>"
        end
        f.puts "</tbody></table>"
        f.puts "</div></div>"

        f.puts ApplicationController.render(partial: 'mushaf_layouts/show', locals: { params: {}, page_number: page, words: words, mushaf: mushaf, compare_words: compare_words })
        f.puts font_size_js

        f.puts "</div></body></html>"
      end
    end
  end

  task diff_qpc_imalei_hafs_text: :environment do
    File.open "../community-data/diff-preview/qcp-diff.html", "wb" do |f|
      f.puts "<html><body>"
      f.puts "<style>@font-face {
  font-family: 'UthmanicHafs1Ver18';
  src: url('./Fonts/UthmanicHafs1 Ver18.ttf');
  font-weight: normal;
  font-style: normal;
  font-display: swap;}
table tr *{font-size: 40px;font-family: 'UthmanicHafs1Ver18'; direction: rtl;}
</style>"
      f.puts diff_styles
      f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
      f.puts "<table class='table'><thead><tr class='sticky'><th>Key</th><th>V17</th><th>V18</th><th class=ltr>Diff <button id=toggle class='btn btn-sm btn-success'>Toggle diff</button></th></tr></thead><tbody>"
      CSV.foreach('data/hafsData_v18.csv', headers: true) do |row|
        key = "#{row['sora']}:#{row['aya_no']}"
        v17_text = Verse.find_by_verse_key(key).text_imlaei_simple.strip
        v18_text = row['aya_text_emlaey'].to_s

        diff = Diffy::Diff.new(v17_text, v18_text).to_s(:html).html_safe
        f.puts "<tr>"
        f.puts "<td>#{key}</td>"
        f.puts "<td>#{v17_text}</td>"
        f.puts "<td>#{v18_text}</td>"
        f.puts "<td>#{diff}</td>"
        f.puts "</tr>"
      end
      f.puts "</tbody></table>"
      f.puts diff_js
      f.puts "</body></html>"
    end
  end

  task diff_qpc_indopak_script: :environment do
    new_words = File.read("data/indopak/v9.3/words.txt").lines
    index = -1
    Chapter.order('id ASC').each do |chapter|
      File.open "../community-data/diff-preview/qpc_indopak_nastaleeq/#{chapter.id}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<style>@font-face {
  font-family: 'AlQuran-IndoPak-by-QuranWB';
  src: url('./Fonts/AlQuran-IndoPak-by-QuranWBW.v3.5-Optimized-with-wakf-lazim.ttf');
  font-weight: normal;
  font-style: normal;
  font-display: swap;}
  table tr *{font-size: 40px;font-family: 'AlQuran-IndoPak-by-QuranWB'; direction: rtl;}
</style>"
        f.puts diff_styles
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<table class='table'><thead><tr class='sticky'><th>WordId</th><th>Indopak v9</th><th>Indopak v9.2.1</th><th class=ltr>Diff <button id=toggle class='btn btn-sm btn-success'>Toggle diff</button></th></tr></thead><tbody>"
        chapter.verses.eager_load(:words).order('verse_index ASC, words.position').each do |verse|
          puts verse.verse_key

          words = verse.words
          words.each do |word|
            new_text = new_words[index += 1].to_s.strip
            old_text = word.text_indopak_nastaleeq.strip

            diff = Diffy::Diff.new(old_text, new_text).to_s(:html).html_safe
            f.puts "<tr>"
            f.puts "<td>#{word.location}</td>"
            f.puts "<td>#{old_text}</td>"
            f.puts "<td>#{new_text}</td>"
            f.puts "<td>#{diff}</td>"
            f.puts "</tr>"
          end
        end

        f.puts "</tbody></table>"
        f.puts diff_js
        f.puts "</body></html>"
      end
    end
  end

  task diff_indopak_nastaleeq_script: :environment do
    indopak = "data/indopak/hanafi-words.txt"

    new_words = File.read(indopak).lines
    index = -1

    Chapter.order('id ASC').each do |chapter|
      File.open "../community-data/diff-preview/indopak_nastaleeq_hanafi9-4/#{chapter.id}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<style>@font-face {
  font-family: 'AlQuran-IndoPak-by-QuranWB';
  src: url('./fonts/AlQuran-IndoPak-by-QuranWBW.v.4.0-WL.woff2');
  }
  table tr *{font-size: 40px; font-family: 'AlQuran-IndoPak-by-QuranWB'; direction: rtl;}
</style>
"
        f.puts diff_styles
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<table class='table table-bordered'><thead><tr class='sticky'><th>WordId</th><th>IndopakCurrent</th><th>Indopak 9.4</th><th class=ltr>Diff <button id=toggle class='btn btn-sm btn-success'>Toggle diff</button></th></tr></thead><tbody>"
        chapter.verses.eager_load(:words).order('verse_index ASC, words.position').each do |verse|
          puts verse.verse_key

          words = verse.words
          words.each do |word|
            new_text = new_words[index += 1].to_s.strip
            old_text = word.text_indopak_nastaleeq.strip

            diff = Diffy::Diff.new(old_text, new_text).to_s(:html).html_safe
            f.puts "<tr>"
            f.puts "<td>#{word.location}</td>"
            f.puts "<td>#{old_text}</td>"
            f.puts "<td>#{new_text}</td>"
            f.puts "<td>#{diff}</td>"
            f.puts "</tr>"
          end
        end

        f.puts "</tbody></table>"
        f.puts diff_js
        f.puts "</body></html>"
      end
    end
  end

  task diff_qpc_and_indopak_script: :environment do
    indopak = "../community-data/indopak/hanafi-words.txt"
    qpc = "../community-data/indopak/qpc-indopak.txt"
    qpc_nastaleeq = "../community-data/indopak/qpc-nastaleeq.txt"

    indopak_words = File.read(indopak).lines
    qpc_words = File.read(qpc).lines
    qpc_nastaleeq_words = File.read(qpc_nastaleeq).lines

    index = 0

    Chapter.order('id ASC').each do |chapter|
      File.open "../community-data/diff-preview/indopak_vs_qpc-9.4/#{chapter.id}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<style>@font-face {
  font-family: 'AlQuran-IndoPak-by-QuranWB';
  src: url('fonts/indopak-nastaleeq-waqf-lazim.woff2');
  }
@font-face{
    font-family: 'KFGQPCNastaleeq';
src: url('fonts/KFGQPCNastaleeq-Regular.woff2');
   }
  table tr *{font-size: 40px;font-family: 'AlQuran-IndoPak-by-QuranWB'; direction: rtl;}
  table tr .qpc-nastaleeq-hafs{font-size: 40px;font-family: 'KFGQPCNastaleeq' !important;  direction: rtl;}
</style>
"
        f.puts diff_styles
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<table class='table table-bordered'><thead>
<tr class='sticky'>
<th>ID</th>
<th>Current</th>
<th>QPC-Nasv10</th>
<th class=ltr title='Current indopak and QPC nastaliq diff'>Diff<button id=toggle class='btn btn-sm btn-success'>Toggle diff</button></th>
<th>IP9.4</th>
<th>QPC9.4</th>
<th class=ltr title='indopak hanafi 9.4 and QPC nastaliq 9.4 diff'>Diff</th>
<th class=ltr title='indopak hanafi 9.4 and QPC nastaliq 9.4 diff'>Diff IP</th>
</tr></thead><tbody>"
        chapter.verses.eager_load(:words).order('verse_index ASC, words.position').each do |verse|
          puts verse.verse_key

          words = verse.words
          words.each do |word|
            indopak_text = indopak_words[index].to_s
            qpc_text = qpc_words[index].to_s
            qpc_nas = qpc_nastaleeq_words[index].to_s
            current_indopak = word.text_indopak_nastaleeq

            index += 1
            current_and_v10_diff = Diffy::Diff.new(current_indopak, qpc_nas).to_s(:html).html_safe
            normal_and_han_diff = Diffy::Diff.new(indopak_text, qpc_text).to_s(:html).html_safe
            ip_diff = Diffy::Diff.new(current_indopak, indopak_text).to_s(:html).html_safe

            f.puts "<tr>"
            f.puts "<td>#{word.location}</td>"
            f.puts "<td>#{current_indopak}</td>"
            f.puts "<td class='qpc-nastaleeq-hafs'>#{qpc_nas}</td>"
            f.puts "<td>#{current_and_v10_diff}</td>"

            f.puts "<td>#{indopak_text}</td>"
            f.puts "<td>#{qpc_text}</td>"
            f.puts "<td>#{normal_and_han_diff}</td>"
            f.puts "<td>#{ip_diff}</td>"
            f.puts "</tr>"
          end
        end

        f.puts "</tbody></table>"
        f.puts diff_js
        f.puts "</body></html>"
      end
    end
  end

  task diff_shafi_and_hanafi_indopak_script: :environment do
    indopak = "../community-data/indopak/hanafi-words.txt"
    qpc = "../community-data/indopak/qpc-indopak.txt"

    indopak_words = File.read(indopak).lines
    qpc_words = File.read(qpc).lines
    index = 0
    Chapter.order('id ASC').each do |chapter|
      File.open "../community-data/diff-preview/hanafi-shafi-diff/#{chapter.id}.html", "wb" do |f|
        f.puts "<html><body>"
        f.puts "<style>@font-face {
  font-family: 'AlQuran-IndoPak-by-QuranWB';
  src: url('./fonts/indopak-nastaleeq-waqf-lazim.woff2');
  }
  table tr *{font-size: 40px;font-family: 'AlQuran-IndoPak-by-QuranWB'; direction: rtl;}
</style>
"
        f.puts diff_styles
        f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        f.puts "<table class='table table-bordered'><thead>
<tr class='sticky'>
<th>ID</th>
<th>Hanafi</th>
<th>Shafi</th>
<th class=ltr title='diff'>Diff<button id=toggle class='btn btn-sm btn-success'>Toggle diff</button></th>
</tr></thead><tbody>"
        chapter.verses.eager_load(:words).order('verse_index ASC, words.position').each do |verse|
          puts verse.verse_key

          words = verse.words
          words.each do |word|
            indopak_text = indopak_words[index].to_s
            qpc_text = qpc_words[index].to_s
            diff = Diffy::Diff.new(indopak_text, qpc_text).to_s(:html).html_safe

            index += 1

            f.puts "<tr>"
            f.puts "<td>#{word.location}</td>"
            f.puts "<td>#{indopak_text}</td>"
            f.puts "<td>#{qpc_text}</td>"
            f.puts "<td>#{diff}</td>"
            f.puts "</tr>"
          end
        end

        f.puts "</tbody></table>"
        f.puts diff_js
        f.puts "</body></html>"
      end
    end
  end
end