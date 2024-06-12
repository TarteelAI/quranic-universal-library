namespace :digital_khatt do
  task create_mushaf_layout: :environment do
    #TODO: one_time:add_verses_mushaf_pages_mapping after this

    mushaf_v1 = Mushaf.find(2) # tarteel is using v1 layout
    mushaf = Mushaf.where(name: 'Digital Khatt').first_or_initialize
    mushaf.attributes = mushaf_v1.attributes.except("id", "name", "created_at", "updated_at")
    mushaf.description = "DigitalKhatt is an Arabic typesetter based on a Metafont-designed parametric font that can generate a glyph with a given width during layout and justification while respecting the curvilinear nature of Arabic letters. See more detail here https://digitalkhatt.org/about"
    mushaf.default_font_name = 'digitalkhatt'

    mushaf.save

    MushafWord.where(mushaf_id: mushaf_v1).eager_load(:word).find_each do |v1_word|
      word = MushafWord.where(
        word_id: v1_word.word_id,
        mushaf_id: mushaf.id
      ).first_or_initialize

      word.attributes = v1_word.attributes.except('id', 'created_at', 'updated_at', 'text', 'mushaf_id')
      word.text = v1_word.word.text_digital_khatt
      word.save
      puts v1_word.word.location
    end

    MushafLineAlignment.where(mushaf_id: mushaf_v1.id).each do |alignment_v2|
      line_alignment = MushafLineAlignment.where(
        mushaf_id: mushaf.id,
        line_number: alignment_v2.line_number,
        page_number: alignment_v2.page_number
      ).first_or_initialize

      line_alignment.attributes = alignment_v2.attributes.except('id', 'mushaf_id')
      line_alignment.save
    end

    1.upto(mushaf.pages_count).each do |page_num|
      page = MushafPage.where(page_number: page_num, mushaf_id: mushaf.id).first_or_initialize

      first_word = MushafWord.where(page_number: page_num, mushaf_id: mushaf.id).order("position_in_page ASC").first
      last_word = MushafWord.where(page_number: page_num, mushaf_id: mushaf.id).order("position_in_page DESC").first

      if first_word && last_word
        verses = Verse.order("verse_index ASC").where("verse_index >= #{first_word.word.verse_id} AND verse_index <= #{last_word.word.verse_id}")
        page.first_verse_id = first_word.word.verse_id
        page.last_verse_id = last_word.word.verse_id
        page.verses_count = verses.size
        page.first_word_id = first_word.word_id
        page.last_word_id = last_word.word_id

        map = {}

        verses.each do |verse|
          if map[verse.chapter_id]
            next
          end

          chapter_verses = verses.where(chapter_id: verse.chapter_id)
          map[verse.chapter_id] = "#{chapter_verses.first.verse_number}-#{chapter_verses.last.verse_number}"
        end

        page.verse_mapping = map
      end
      page.save(validate: false)
      puts page.id
    end
  end

  task import: :environment do
    url = "https://static-cdn.tarteel.ai/cms-data/digital_khatt_verses.json"
    verses_data = JSON.parse URI.open(url).read

    verses_data.each do |id, text|
      Verse.find(id).update_column :text_digital_khatt, text.to_s.strip
    end

    url = "https://static-cdn.tarteel.ai/cms-data/digital_khatt_words.json"
    words_data = JSON.parse URI.open(url).read

    words_data.each do |id, text|
      w = Word.find(id)
      puts w.location

      w.update_column :text_digital_khatt, text.to_s.strip
    end
    puts "done"
  end

  task export: :environment do
    File.open "digital_khatt_verses.json", 'wb' do |file|
      data = {}

      Verse.pluck(:id, :text_digital_khatt).each do |v|
        data[v[0]] = v[1]
      end

      file.puts data.to_json
    end

    File.open "digital_khatt_words.json", 'wb' do |file|
      data = {}

      Word.pluck(:id, :text_digital_khatt).each do |v|
        data[v[0]] = v[1]
      end

      file.puts data.to_json
    end
  end

  task prepare_ayah_text: :environment do
    @ayahs = []
    @last_line_was_ayah = false
    @current_surah = 0
    @current_ayah = ""

    AYAH_MARKER = Regexp.new "۝[١٢٣٤٥٦٧٨٩٠]+"

    def extract_ayahs(page)
      page.each do |line|
        if line.start_with?("سُورَةُ")
          @last_line_was_ayah = true
          @current_surah += 1
          puts "===> Surah: #{@current_surah}"
          next
        end

        if @last_line_was_ayah
          @last_line_was_ayah = false

          if @current_surah > 1 && line.start_with?("بِسْمِ ٱللَّهِ")
            next
          end
        end

        if line.include?('۝')
          line_text = line.dup
          markers = line.scan(AYAH_MARKER)

          markers.each do |m|
            index = line_text.index(m)
            part = line_text.slice!(0, index + m.length)

            @current_ayah += " #{part}"
            @ayahs << @current_ayah.strip
            @current_ayah = ""
          end

          @current_ayah = line_text
        else
          @current_ayah += " #{line} "
        end
      end
    end

    pages = JSON.parse File.read('data/digital_khat/text.json').strip.gsub("\n", "")

    pages.each do |page|
      extract_ayahs(page)
    end

    @ayahs.each_with_index do |ayah, index|
      verse = Verse.find_by(verse_index: index + 1)
      verse.update_columns(text_digital_khatt: ayah.strip)
    end

    # edge cases
    Verse.find(6099).update text_digital_khatt: "وَٱلتِّينِ وَٱلزَّيْتُونِ ۝١"
    Verse.find(6126).update text_digital_khatt: "إِنَّآ أَنزَلْنَٰهُ فِي لَيْلَةِ ٱلْقَدْرِ ۝١"
  end

  task prepare_word_text: :environment do
    def merge_rub_marker(words)
      if words[0] == '۞'
        merged = "#{words[0]}#{words[1]}"
        words.shift(2)
        words.unshift(merged)
      end

      words
    end

    def split(id)
      merge_rub_marker Verse.find(id).text_digital_khatt.split(/\s+/)
    end

    def update(id, words)
      verse = Verse.find id
      verse.words.each_with_index do |word, i|
        word.update_columns(text_digital_khatt: words[i])
      end
    end

    # fixed: 188, 1166, 1744 badama
    # 1809, 3179, 3727, 3918
    # [188, 1166, 1744, 1809, 3179, 3727, 3918, 6099, 6126]
    issues = []

    ["بِّسْمِ", "ٱللَّهِ", "ٱلرَّحْمَٰنِ", "ٱلرَّحِيمِ", "وَٱلتِّينِ", "وَٱلزَّيْتُونِ", "۝١"]

    Verse.find_each do |verse|
      digital_khatt_texts = merge_rub_marker verse.text_digital_khatt.split(/\s+/)

      if digital_khatt_texts.size != verse.words.size
        issues.push verse.id
        puts "Verse #{verse.id} has different word count"
        next
      end

      verse.words.each_with_index do |word, i|
        word.update_columns(text_digital_khatt: digital_khatt_texts[i])
      end
    end
  end
end
