namespace :surah_name_glyphs do
  task update_chapter_name_glyphs: :environment do
    codes = [
      'ﱅ ',
      'ﱆ ',
      'ﱇ ',
      'ﱊ ',
      'ﱋ ',
      'ﱎ ',
      'ﱏ ',
      'ﱑ ',
      'ﱒ ',
      'ﱓ ',
      'ﱕ ',
      'ﱖ ',
      'ﱘ ',
      'ﱚ ',
      'ﱛ ',
      'ﱜ ',
      'ﱝ ',
      'ﱞ ',
      'ﱡ ',
      'ﱢ ',
      'ﱤ ',
      'ﭑ ',
      'ﭒ ',
      'ﭔ ',
      'ﭕ ',
      'ﭗ ',
      'ﭘ ',
      'ﭚ ',
      'ﭛ ',
      'ﭝ ',
      'ﭞ ',
      'ﭠ ',
      'ﭡ ',
      'ﭣ ',
      'ﭤ ',
      'ﭦ ',
      'ﭧ ',
      'ﭩ ',
      'ﭪ ',
      'ﭬ ',
      'ﭭ ',
      'ﭯ ',
      'ﭰ ',
      'ﭲ ',
      'ﭳ ',
      'ﭵ ',
      'ﭶ ',
      'ﭸ ',
      'ﭹ ',
      'ﭻ ',
      'ﭼ ',
      'ﭾ ',
      'ﭿ ',
      'ﮁ ',
      'ﮂ ',
      'ﮄ ',
      'ﮅ ',
      'ﮇ ',
      'ﮈ ',
      'ﮊ ',
      'ﮋ ',
      'ﮍ ',
      'ﮎ ',
      'ﮐ ',
      'ﮑ ',
      'ﮓ ',
      'ﮔ ',
      'ﮖ ',
      'ﮗ ',
      'ﮙ ',
      'ﮚ ',
      'ﮜ ',
      'ﮝ ',
      'ﮟ ',
      'ﮠ ',
      'ﮢ ',
      'ﮣ ',
      'ﮥ ',
      'ﮦ ',
      'ﮨ ',
      'ﮩ ',
      'ﮫ ',
      'ﮬ ',
      'ﮮ ',
      'ﮯ ',
      'ﮱ ',
      '﮲ ',
      '﮴ ',
      '﮵ ',
      '﮷ ',
      '﮸ ',
      '﮺ ',
      '﮻ ',
      '﮽ ',
      '﮾ ',
      '﯀ ',
      '﯁ ',
      'ﯓ ',
      'ﯔ ',
      'ﯖ ',
      'ﯗ ',
      'ﯙ ',
      'ﯚ ',
      'ﯜ ',
      'ﯝ ',
      'ﯟ ',
      'ﯠ ',
      'ﯢ ',
      'ﯣ ',
      'ﯥ ',
      'ﯦ ',
      'ﯨ ',
      'ﯩ ',
      'ﯫ'
    ]
    v1_ligatures = {surah_icon: 'surah'}
    v2_ligatures = {}
    v4_ligatures = {surah_icon: 'surah'}
    surah_header_ligatures = {}

    Chapter.find_each do |chapter|
      icon = "surah#{chapter.chapter_number.to_s.rjust(3, '0')}"
      v1_ligatures["surah-#{chapter.chapter_number}"] = icon
      v4_ligatures["surah-#{chapter.chapter_number}"] = icon
      v2_ligatures["surah-#{chapter.chapter_number}"] = icon
      surah_header_ligatures["surah-#{chapter.chapter_number}"] = codes[chapter.chapter_number - 1]
      #
      # chapter.update_columns(
      #   v1_chapter_glyph_code: icon,
      #   v2_chapter_glyph_code: icon,
      #   v4_chapter_glyph_code: icon,
      #   color_header_chapter_glyph_code: codes[chapter.chapter_number - 1],
      #   )
    end

    # v2
    v2 = ResourceContent.find(1520)
    v2.set_meta_value("ligatures", v2_ligatures.to_json)
    v2.save

    # surah header
    header = ResourceContent.find(1523)
    header.set_meta_value("ligatures", surah_header_ligatures.to_json)
    header.save

    # v1
    v1 = ResourceContent.find(1522)
    v1.set_meta_value("ligatures", v1_ligatures.to_json)
    v1.save

    # v4
    v4 = ResourceContent.find(1521)
    v4.set_meta_value("ligatures", v4_ligatures.to_json)
    v4.save

    common_ligatures = {
      surah_header: 'header',
      makkah: 'makkah',
      madinah: 'madinah',
      bismillah: '﷽',
      marker: 'marker-half',
      marker2: 'marker-full',
      ayah_open1: 's1open',
      ayah_close1: 's1close',
      ayah_open2: 's2open',
      ayah_close2: 's2close',
      ayah_open3: 's3open',
      ayah_close3: 's3close',
    }
    Juz.find_each do |juz|
      common_ligatures["juz-#{juz.id}-name"]= "j#{juz.juz_number.to_s.rjust(3, '0')}"
      common_ligatures["juz-#{juz.id}-number"]= "juz#{juz.juz_number.to_s.rjust(3, '0')}"
    end

    j = ResourceContent.find(1524)
    j.set_meta_value("ligatures", common_ligatures.to_json)
    j.save
  end

  task generate_glyphs: :environment do
    def surah_glyph_code(surah_number)
      # Let's use 0xE000 for surah icon, and 0xE000 + surah number for names
      base_codepoint = 0xE000
      codepoint = base_codepoint + surah_number

      ("%04X" % codepoint).downcase
    end

    CSV.open("surah-name-code-points.csv", "wb") do |csv|
      csv << ['Surah number', 'Ligature', 'Code', 'Name', 'Name Arabic']

      Chapter.order('chapter_number ASC').each do |chapter|
        padded = chapter.chapter_number.to_s.rjust(3, '0')
        csv << [
          chapter.chapter_number,
          "surah#{padded},s#{padded}",
          surah_glyph_code(chapter.chapter_number),
          chapter.name_simple,
          chapter.name_arabic
        ]
      end
    end
  end

  task generate_preview: :environment do
    def styles
      "<style>
@font-face {
  font-family: 'surah-name-v4';
  src:  url('fonts/surah-names/v4/surah-name-v4.eot');
  src:  url('fonts/surah-names/v4/surah-name-v4.eot') format('embedded-opentype'),
    url('fonts/surah-names/v4/surah-name-v4.ttf') format('truetype'),
    url('fonts/surah-names/v4/surah-name-v4.woff') format('woff'),
    url('fonts/surah-names/v4/surah-name-v4.svg') format('svg');
}
@font-face {
  font-family: 'surah-name-v1';
  src:  url('fonts/surah-names/v1/surah-name-v1.eot');
  src:  url('fonts/surah-names/v1/surah-name-v1.eot') format('embedded-opentype'),
    url('fonts/surah-names/v1/surah-name-v1.ttf') format('truetype'),
    url('fonts/surah-names/v1/surah-name-v1.woff') format('woff'),
    url('fonts/surah-names/v1/surah-name-v1.svg') format('svg');
}
@font-face {
  font-family: 'surah-name-v2';
  src:  url('fonts/surah-names/v2/surah-name-v2.woff2'),
    url('fonts/surah-names/v2/surah-name-v2.ttf') format('truetype'),
    url('fonts/surah-names/v2/surah-name-v2.woff') format('woff'),
    url('fonts/surah-names/v2/surah-name-v2.svg') format('svg');
}
@font-face{
 font-family: 'surah-header';
  src:  url('fonts/surah-header/QCF_SurahHeader_COLOR-Regular.woff2');
  src:  url('fonts/surah-header/QCF_SurahHeader_COLOR-Regular.ttf');
}

@font-face{
 font-family: 'juz';
  src:  url('fonts/common/quran-common.woff');
}
.juz{
  font-family: 'juz' !important;
}

.v4 {
  font-family: 'surah-name-v4' !important;
}
.v1 {
  font-family: 'surah-name-v1' !important;
}
.v2{
  font-family: 'surah-name-v2' !important;
}
.surah-header{
  font-family: 'surah-header' !important;
}

.v1, .v4, .v2{
  font-size:30px;
    text-align: right;
    direction: rtl;
 font-weight: normal;
  font-style: normal;
  font-display: block;
speak: never;
  font-style: normal;
  font-weight: normal;
  font-variant: normal;
  text-transform: none;
  line-height: 1;

  letter-spacing: 0;
  -webkit-font-feature-settings: 'liga';
  -moz-font-feature-settings: 'liga=1';
  -moz-font-feature-settings: 'liga';
  -ms-font-feature-settings: 'liga' 1;
  font-feature-settings: 'liga';
  -webkit-font-variant-ligatures: discretionary-ligatures;
  font-variant-ligatures: discretionary-ligatures;

  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
.surah-header{
font-size: 130px
}
      </style>"
    end

    def surah_glyph_code(surah_number)
      base_codepoint = 0xE000
      codepoint = base_codepoint + surah_number
      codepoint.chr
    end

    def surah_header_code(surah_number)
      codes = [
        'ﱅ ',
        'ﱆ ',
        'ﱇ ',
        'ﱊ ',
        'ﱋ ',
        'ﱎ ',
        'ﱏ ',
        'ﱑ ',
        'ﱒ ',
        'ﱓ ',
        'ﱕ ',
        'ﱖ ',
        'ﱘ ',
        'ﱚ ',
        'ﱛ ',
        'ﱜ ',
        'ﱝ ',
        'ﱞ ',
        'ﱡ ',
        'ﱢ ',
        'ﱤ ',
        'ﭑ ',
        'ﭒ ',
        'ﭔ ',
        'ﭕ ',
        'ﭗ ',
        'ﭘ ',
        'ﭚ ',
        'ﭛ ',
        'ﭝ ',
        'ﭞ ',
        'ﭠ ',
        'ﭡ ',
        'ﭣ ',
        'ﭤ ',
        'ﭦ ',
        'ﭧ ',
        'ﭩ ',
        'ﭪ ',
        'ﭬ ',
        'ﭭ ',
        'ﭯ ',
        'ﭰ ',
        'ﭲ ',
        'ﭳ ',
        'ﭵ ',
        'ﭶ ',
        'ﭸ ',
        'ﭹ ',
        'ﭻ ',
        'ﭼ ',
        'ﭾ ',
        'ﭿ ',
        'ﮁ ',
        'ﮂ ',
        'ﮄ ',
        'ﮅ ',
        'ﮇ ',
        'ﮈ ',
        'ﮊ ',
        'ﮋ ',
        'ﮍ ',
        'ﮎ ',
        'ﮐ ',
        'ﮑ ',
        'ﮓ ',
        'ﮔ ',
        'ﮖ ',
        'ﮗ ',
        'ﮙ ',
        'ﮚ ',
        'ﮜ ',
        'ﮝ ',
        'ﮟ ',
        'ﮠ ',
        'ﮢ ',
        'ﮣ ',
        'ﮥ ',
        'ﮦ ',
        'ﮨ ',
        'ﮩ ',
        'ﮫ ',
        'ﮬ ',
        'ﮮ ',
        'ﮯ ',
        'ﮱ ',
        '﮲ ',
        '﮴ ',
        '﮵ ',
        '﮷ ',
        '﮸ ',
        '﮺ ',
        '﮻ ',
        '﮽ ',
        '﮾ ',
        '﯀ ',
        '﯁ ',
        'ﯓ ',
        'ﯔ ',
        'ﯖ ',
        'ﯗ ',
        'ﯙ ',
        'ﯚ ',
        'ﯜ ',
        'ﯝ ',
        'ﯟ ',
        'ﯠ ',
        'ﯢ ',
        'ﯣ ',
        'ﯥ ',
        'ﯦ ',
        'ﯨ ',
        'ﯩ ',
        'ﯫ'
      ]

      codes[surah_number - 1]
    end

    def get_juz_name_glyph_code(number)
      base_codepoint = 0xE8FF
      codepoint = base_codepoint + number
      codepoint.chr
    end

    def get_juz_number_glyph_code(number)
      base_codepoint = 0xE000
      codepoint = base_codepoint + number
      codepoint.chr
    end

    File.open "tmp/surah_names/surah_name_preview.html", "wb" do |f|
      f.puts "<html><head><meta charset='utf-8'></head><body>"
      f.puts styles
      f.puts "<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css' rel='stylesheet'  crossorigin='anonymous'>"
      f.puts "<table class='table table-bordered rtl'><thead>
<tr class='sticky'>
<th>Id</th>
<th>Name</th>
<th>V1</th>
<th>V2</th>
<th>V4</th>
<th>Header</th>
</tr></thead><tbody class=rtl>"
      tr = "<tr>
               <td>-</td>
               <td>-</td>
               <td><div class=v1>surah-icon</div></td>
               <td></td>
               <td><div class=v4>surah-icon</div></td>
               <td></td>
              </tr>"
      f.puts tr
      Chapter.order('chapter_number asc').each do |chapter|
        chapter_number = chapter.chapter_number.to_s.rjust(3, '0')

        tr = "<tr>
               <td>#{chapter.chapter_number}</td>
               <td>#{chapter.name_arabic}</td>
               <td><div class=v1>s#{chapter_number} - surah#{chapter_number} - #{surah_glyph_code(chapter.chapter_number)}</div></td>
               <td><div class=v2>s#{chapter_number} - surah#{chapter_number} - #{surah_glyph_code(chapter.chapter_number)}</div></td>
               <td><div class=v4>s#{chapter_number} - surah#{chapter_number} - #{surah_glyph_code(chapter.chapter_number)}</div></td>
               <td class='surah-header'>#{surah_header_code(chapter.chapter_number)}</td>
              </tr>"
        f.puts tr
      end
      f.puts "</tbody></table>"

      f.puts "<h2>Juz Preview</h2>"
      f.puts "<table class='table table-bordered rtl'><thead>
<tr class='sticky'>
<th>Id</th>
<th>Name ligature</th>
<th>Name code</th>

<th>Number</th>
<th>Number code</th>

</tr></thead><tbody class=rtl>"

      Juz.order('juz_number asc').each do |juz|
        number = juz.juz_number.to_s.rjust(3, '0')

        tr = "<tr>
               <td>#{juz.juz_number}</td>
               <td><div class=juz>j#{number}</div></td>
               <td><div class=juz>#{get_juz_name_glyph_code(juz.juz_number)}</div></td>
               <td><div class=juz>juz#{number}</div></td>
               <td><div class=juz>#{get_juz_number_glyph_code(juz.juz_number)}</div></td>
              </tr>"
        f.puts tr
      end
      f.puts "</tbody></table>"
      f.puts "</body></html>"


    end
  end
end