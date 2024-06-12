namespace :char_info do
  task generate_report: :environment do
    DIALECTIC = /[\u064b-\u0657\u065e\u0660]?/
    LETTERS = /[\u0621-\u063a\u0641-\u064a]/
    #[\u0600-\u06FF\u0750-\u077F\u0000-\u007F]
    REG = /[\u0621-\u063a\u0641-\u064a][\u064b-\u0657\u065e\u0660]*/

    require "unicode/name"

    def generate_font_face(font)
      "@font-face {
        font-family: '#{font}';
        src: url('../fonts/#{font}.woff2');
       }
       .#{font} .char{font-family: #{font}; font-size: 40px; direction: rtl; unicode-bidi: plaintext;}
       .sticky{position: sticky;top:20px;background: #fff;}
       "
    end

    def jquery
      "<script src='https://code.jquery.com/jquery-3.6.0.min.js'></script>"
    end

    def font_size_js
      "<script>
     addEventListener('click', e => {
      const node = e.target;
      navigator.clipboard.writeText(node.textContent);
      console.log(node.textContent, ' copied to clipboard')
    }, false);

    document.querySelectorAll('.font-size-slider').forEach((slider) => {
      slider.oninput = (event) => {
        const fontSize = event.target.value;

        $('.char').css('font-size', `${fontSize}px`);
        $('#size').html(fontSize)
      }
    });
</script>"
    end

    def highlight(text, match)
      # &zwj;
      text.gsub(match) do |matched|
        "<span class=hlt>#{matched}</span>"
      end
    end

    def generate(texts, filename, font)
      texts = texts.join().chars
      uniq_chars = texts.uniq.sort
      reg = "1571-1594 1601-1610"

      # 0621 hamza
      # \u0623-\u063a
      tashkeel_chars = texts.join().split(/s*/)

      CSV.open("../community-data/char-info/mushaf/#{filename}.csv", "wb") do |csv|
        csv << ['Char', 'Name', 'Count', 'Decimal', 'HTML', 'Hexa', 'Codepoints', 'Link']

        uniq_chars.each_with_index do |char, i|
          decimal = char.ord
          html_entity = "&##{decimal};"
          hex = char.ord.to_s(16).rjust(4, '0')
          name = Unicode::Name.of(char)
          link = "https://www.compart.com/en/unicode/U+#{hex}"
          count = texts.count(char)
          char_filename = name.to_s.underscore.tr ' ', '_'

          csv << [char, name, count, decimal, html_entity, hex, char.codepoints, link]
          row = "<td>#{i + 1}</td><td><a href='../chars/#{char_filename}.html' target=_blank>#{name}</a></td> <td class='char'>#{char}</td> <td>#{count}</td> <td>#{decimal}</td> <td><span class=char>#{html_entity.html_safe}</span></td> <td>#{hex}</td> <td>#{char.codepoints}</td> <td><a href=#{link} target=_blank>open</a> </td>"
          html.puts "<tr>#{row}</tr>"
        end
      end

      File.open("../community-data/char-info/mushaf/#{filename}.rb", "wb") do |char_file|
        uniq_chars.each_with_index do |char, i|
          name = Unicode::Name.of(char).to_s.sub(/ARABIC|LETTER/, '').strip.gsub(/\s+/, ' ').gsub(" ", "_")
          hex = char.ord.to_s(16).rjust(4, '0')

          char_file.puts "#{name} = Letter.new(name: '#{name}', char: '#{char}', unicode:" + '"'+ "\\u#{hex}" + '")'
        end
      end

      File.open "../community-data/char-info/mushaf/#{filename}.html", "wb" do |html|
        html.puts "<html><body>"
        html.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        html.puts "<style>#{generate_font_face(font)}</style>"
        html.puts jquery
        html.puts "<div class='row my-4 sticky'><div class=col-12><div style='width: 100%;margin: 0 5px;text-align: center;direction: ltr;font-size: 20px'>
    Font size: current(<span id='size'>40</span>)<input type='range' min='15' max='100' value='40' class='font-size-slider'>
  </div></div></div>"
        html.puts "<table class='table table-hover #{font}'>
          <thead><tr class='sticky'>
               <th>#</th>
               <th style='width: 100px'>Name</th>
               <th>Char</th>
               <th>Count</th>
               <th>Decimal</th>
               <th>HTML</th>
               <th>Hexa</th>
               <th>Codepoints</th>
               <th>Link</th></tr></thead><tbody>"

        html.puts "</tbody></table>"
        html.puts font_size_js
        html.puts "</body></html>"

        tashkeel_html.puts "</tbody></table>"
        tashkeel_html.puts font_size_js
        tashkeel_html.puts "</body></html>"
      end

      uniq_chars
    end

    chars = []

    chars << generate(Verse.pluck(:text_qpc_hafs), 'qpc_hafs', 'qpc_hafs')
    chars << generate(Verse.pluck(:text_indopak_nastaleeq), 'indopak', 'indopak')
    chars << generate(Verse.pluck(:text_uthmani), 'uthmani', 'me_quran')
    chars = chars.flatten.uniq

    chars.each do |char|
      name = Unicode::Name.of(char).to_s

      if name.blank? || name.include?('SPACE') || name.include?('DIGIT')
        next
      end

      qpc_hafs_words = Word.where("text_qpc_hafs like ?", "%#{char}%").pluck(:id)
      utmani_words = Word.where("text_uthmani like ?", "%#{char}%").pluck(:id)
      indopak_words = Word.where("text_indopak_nastaleeq like ?", "%#{char}%").pluck(:id)

      words = Word.where(id: (qpc_hafs_words + utmani_words + indopak_words).uniq)
      filename = name.to_s.underscore.tr ' ', '_'

      File.open "../community-data/char-info/chars/#{filename}.html", "wb" do |html|
        html.puts "<html><body>"
        html.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
        html.puts "<style>.hlt{color:red;    unicode-bidi: bidi-override;}#{generate_font_face('indopak')}</style>"
        html.puts "<style>#{generate_font_face('qpc_hafs')}</style>"
        html.puts "<style>#{generate_font_face('me_quran')}</style>"

        html.puts jquery

        html.puts "<div class='row my-4 sticky'><div class=col-12><div style='width: 100%;margin: 0 5px;text-align: center;direction: ltr;font-size: 20px'>
    Font size: current(<span id='size'>40</span>)<input type='range' min='15' max='100' value='40' class='font-size-slider'>
  </div></div></div>"
        html.puts "<table class='table table-hover'>
          <thead><tr class='sticky'>
               <th>#</th>
               <th>Id</th>
               <th>QPC Hafs</th>
               <th>Me Quran</th>
               <th>Indopak</th>
               </tr></thead><tbody>"

        words.order('verse_id ASC').each_with_index do |word, i|
          html.puts "<tr><td>#{i + 1}</td> <td><a href='http://tools.quran.com/admin/words/#{word.id}' target=_blank>#{word.id}</td><td class=qpc_hafs><span class=char>#{highlight word.text_qpc_hafs, char}</span></td> <td class=me_quran><span class=char>#{highlight word.text_uthmani, char}</span> </td> <td class=indopak><span class=char>#{highlight word.text_indopak_nastaleeq, char}</span></td></tr>"
        end

        html.puts "</tbody></table>"
        html.puts font_size_js
        html.puts "</body></html>"
      end
    end
  end
end