# qortobi: https://quran.ksu.edu.sa/tafseer/qortobi-saadi/sura2-aya1.html

module Importer
  class QuranEncTafsir < Base
    STRIP_TEXT_REG = /^[\[\(]*(\d+[\s-]*[\d]*)[\]\)\s.-]*/
    COLORS_TO_CSS_CLASS_MAPPING = {}
    SANITIZER = Utils::TextSanitizer::TafsirSanitizer.new

    COLOR_MAPPING = {
      tabary: {
        '008000': 'arabic qpc-hafs green', # Lime green
        '950000': 'red', # Burgundy, usually name of sahabi, surah
        '006d98': 'blue', # teal blue, usually quote (qala)
        '947721': 'arabic qpc-hafs brown',
        '707070': 'reference'
      },
      katheer: {
        '008000': 'arabic qpc-hafs',
        '006d98': 'blue', # teal blue
        '950000': 'red',
        '707070': 'reference brown'
      },
      baghawy: {
        '008000': 'green', # reference if there is number in text, otherwise arabic
        '950000': 'arabic qpc-hafs',
        '947721': 'arabic qpc-hafs',
        '006d98': 'blue',
        "707070": 'reference'
      },
      saadi: {
        '006d98': 'blue',
        '947721': 'arabic qpc-hafs brown',
        '950000': 'red',
        '707070': 'arabic qpc-hafs',
        '008000': 'arabic qpc-hafs green'
      },
      moyassar: {
        "006d98": 'blue',
        "6c6c00": 'brown',
        '950000': 'red',
        '008000': 'green',
        "947721": 'arabic qpc-hafs brown'
      }
    }

    TAFSIR_MAPPING = {
      arabic_moyassar: { id: 16, key: 'moyassar' },
      saadi: { id: 91 },
      baghawy: { id: 94 },
      katheer: { id: 14 },
      tabary: { id: 15 },
      russian_mokhtasar: {
        id: 178,
        language: 138,
        name: 'Russian Al-Mukhtasar',
        author: 'Tafsir Center for Quranic Studies'
      },
      english_mokhtasar: {
        id: 171,
        language: 38,
        name: 'English Al-Mukhtasar',
        author: 'Tafsir Center for Quranic Studies'
      },
      arabic_mokhtasar: {
        id: 905,
        language: 9,
        name: 'Arabic Al-Mukhtasar in interpreting the Noble Quran',
        author: 'Tafsir Center for Quranic Studies'
      },
      turkish_mokhtasar: {
        id: 172,
        language: 167,
        name: 'Turkish Al-Mukhtasar in Interpreting the Noble Quran',
        author: 'Tafsir Center'
      },
      french_mokhtasar: {
        id: 173,
        language: 49,
        name: 'French Abridged Explanation of the Quran',
        author: 'Tafsir Center for Quranic Studies'
      },
      indonesian_mokhtasar: {
        id: 174,
        language: 67,
        name: 'Indoniesua Al-Mukhtasar in Interpreting the Noble Quran',
        author: 'Tafsir Center for Quranic Studies'
      },
      vietnamese_mokhtasar: {
        id: 177,
        language: 177,
        name: 'Vietnamese Al-Mukhtasar in interpreting the Noble Quran',
        author: 'Tafsir Center'
      },
      bosnian_mokhtasar: {
        id: 175,
        language: 23,
        name: 'Bosnian Abridged Explanation of the Quran',
        author: 'Tafsir Center'
      },
      italian_mokhtasar: {
        id: 176,
        language: 74,
        name: 'Italian Al-Mukhtasar in interpreting the Noble Quran',
        author: 'Tafsir Center'
      },
      spanish_mokhtasar: {
        id: 776,
        language: 40,
        name: 'Spanish Abridged Explanation of the Quran',
        author: 'Tafsir Center for Quranic Studies'
      },
      tagalog_mokhtasar: {
        id: 179,
        language: 164,
        name: 'Filipino (Tagalog) Al-Mukhtasar in interpreting the Noble Quran',
        author: 'Tafsir Center'
      },
      bengali_mokhtasar: {
        id: 180,
        language: 20,
        name: 'Bengali Abridged Explanation of the Quran',
        info: "Bengali translation of \"Abridged Explanation of the Quran\" by Tafsir Center of Quranic Studies",
        author: 'Tafsir Center for Quranic Studies'
      },
      persian_mokhtasar: {
        id: 181,
        language: 43,
        name: 'Persian Al-Mukhtasar in interpreting the Noble Quran',
        author: 'Tafsir Center'
      },
      chinese_mokhtasar: {
        id: 182,
        language: 185,
        name: 'Chinese Abridged Explanation of the Quran',
        author: 'Tafsir Center of Quranic Studies'
      },
      japanese_mokhtasar: {
        id: 183,
        language: 76,
        name: 'Japanese Abridged Explanation of the Quran',
        author: 'Tafsir Center of Quranic Studies'
      },
      assamese_mokhtasar: {
        id: 790,
        language: 10,
        name: 'Assamese Abridged Explanation of the Quran',
        author: 'Tafsir Center of Quranic Studies'
      },
      malayalam_mokhtasar: {
        id: 791,
        language: 106,
        name: 'Malayalam Abridged Explanation of the Quran',
        author: 'Tafsir Center of Quranic Studies'
      },
      khmer_mokhtasar: {
        id: 792,
        language: 84,
        name: 'Khmer Abridged Explanation of the Quran',
        author: 'Tafsir Center of Quranic Studies'
      },
      uzbek_mokhtasar: {
        id: 1275,
        name: 'Uzbek mokhtasar',
        language: ''
      },
      uyghur_mokhtasar: {
        id: 1274,
      },
      thai_mokhtasar: {

      },
      telugu_mokhtasar: {

      },
      tamil_mokhtasar: {

      },
      serbian_mokhtasar: {

      },
      sinhalese_mokhtasar: {

      },
      pashto_mokhtasar: {

      },
      kyrgyz_mokhtasar: {

      },
      kurdish_mokhtasar: {

      },
      hindi_mokhtasar: {

      },
      fulani_mokhtasar: {

      },
      azeri_mokhtasar: {

      },

      arabic_seraj: {
        id: 908,
        language: 9,
        name: 'Asseraj fi Bayan Gharib AlQuran',
        author: 'Muhammad Al-Khudairi',
        native: 'محمد الخضيري'
      }
    }

    def import_all_abridge
      TAFSIR_MAPPING.keys.each do |key|
        import(key)
      end
    end

    def import(quran_enc_key)
      resource = find_or_create_resource(quran_enc_key)

      Verse.unscoped.order('id ASC').find_each do |verse|
        url = "https://quranenc.com/api/v1/translation/aya/#{quran_enc_key}/#{verse.chapter_id}/#{verse.verse_number}"

        data = get_json(url)['result']
        content = data['translation']
        verse = Verse.find_by(verse_key: "#{data['sura']}:#{data['aya']}")

        if respond_to?("import_#{quran_enc_key}")
          send("import_#{quran_enc_key}", content, verse, resource)
        else
          import_tafsir(content, verse, resource, quran_enc_key)
        end
      end

      resource.set_meta_value('synced-at', DateTime.now)
      resource.run_draft_import_hooks
      resource.save
    end

    def download(quran_enc_key)
      resource = find_or_create_resource(quran_enc_key)
      raise "Resource Content is not configured for #{quran_enc_key}" if resource.blank?

      FileUtils.mkdir_p("data/quranenc-tafsirs/#{quran_enc_key}")

      1.upto(114).each do |c|
        download_chapter(c, quran_enc_key)
      end
    end

    def import(quran_enc_key, use_cached_data: false)
      resource = find_or_create_resource(quran_enc_key)

      if use_cached_data
        source_path = "data/quranenc-tafsirs/#{quran_enc_key}"

        Dir["#{source_path}/*.json"].each do |file|
          data = Oj.load(File.read(file))
          if data.blank?
            # grouping
            next
          end

          data = data[0]
          content = data['tafsir']
          verse = Verse.find_by(verse_key: "#{data['sura']}:#{data['aya']}")

          if verse.blank?
            next
          end

          import_tafsir(content, verse, resource, quran_enc_key)
        end
      else
        Verse.order('id ASC').each do |v|
          puts v.verse_key

          data = fetch_tafsir(quran_enc_key, v)

          if data.present? && data[0]['tafsir'].present?
            data = data[0]
            content = data['tafsir']
            verse = Verse.find_by(verse_key: "#{data['sura']}:#{data['aya']}")

            import_tafsir(content, v, resource, quran_enc_key) if verse
          end
        end
      end

      resource.run_draft_import_hooks
    end

    protected

    def find_or_create_resource(quran_enc_key)
      mapping = TAFSIR_MAPPING[quran_enc_key.to_sym]
      raise "mapping not found for tafsir #{quran_enc_key}. Please add the mapping and try again" if mapping.nil?

      resource = if mapping[:id]
                   ResourceContent.find(mapping[:id])
                 else
                   ResourceContent.where("meta_data ->> 'quranenc-key' = '#{quran_enc_key}'").first_or_initialize
                 end

      force_update = true

      if resource.new_record? || force_update
        language = Language.find(mapping[:language])
        data_source = DataSource.find_or_create_by(name: 'Quranenc', url: 'https://quranenc.com')

        author_name = mapping[:author]
        author = Author.where(name: author_name).first_or_create

        resource.set_meta_value('source', 'quranenc')
        resource.set_meta_value('quranenc-key', quran_enc_key)
        resource.data_source = data_source
        resource.language = language
        resource.language_name = language.name.downcase
        resource.author_name = author.name
        resource.name = mapping[:name]
        resource.resource_info = resource.resource_info.presence || mapping[:info]
        resource.approved = false
      end

      resource.cardinality_type = ResourceContent::CardinalityType::OneVerse
      resource.resource_type = ResourceContent::ResourceType::Content
      resource.sub_type = ResourceContent::SubType::Tafsir
      resource.save(validate: false)

      resource
    end

    def import_arabic_seraj(content, verse, resource) end

    def import_tafsir(content, verse, resource, quran_enc_key)
      text = sanitize_text(content, quran_enc_key)

      draft_tafsir = Draft::Tafsir
                       .where(
                         resource_content_id: resource.id,
                         verse_id: verse.id
                       ).first_or_initialize

      existing_tafsir = Tafsir
                          .where(resource_content_id: resource.id)
                          .where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse.id)
                          .first

      draft_tafsir.set_meta_value('source_data', { text: content })
      draft_tafsir.tafsir_id = existing_tafsir&.id
      draft_tafsir.current_text = existing_tafsir&.text
      draft_tafsir.draft_text = text
      draft_tafsir.text_matched = existing_tafsir&.text == text
      draft_tafsir.imported = false
      draft_tafsir.verse_key = verse.verse_key

      draft_tafsir.group_verse_key_from = verse.verse_key
      draft_tafsir.group_verse_key_to = verse.verse_key
      draft_tafsir.group_verses_count = 1
      draft_tafsir.start_verse_id = verse.id
      draft_tafsir.end_verse_id = verse.id
      draft_tafsir.group_tafsir_id = verse.id

      draft_tafsir.save(validate: false)
    end

    def sanitize_text(text, quran_enc_key)
      binding.pry if @DEBUG.nil?
      color_mapping = COLOR_MAPPING[quran_enc_key.to_sym]
      text = text.gsub(STRIP_TEXT_REG, '').strip
      SANITIZER.sanitize(text, color_mapping: color_mapping).html
    end

    def download_chapter(chapter_id, quran_enc_key)
      Verse.where(chapter_id: chapter_id).order('verse_number asc').each do |v|
        next if File.exist?("data/quranenc-tafsirs/#{quran_enc_key}/#{v.verse_key}.json")

        File.open("data/quranenc-tafsirs/#{quran_enc_key}/#{v.verse_key}.json", "wb") do |file|
          text = fetch_tafsir(quran_enc_key, v)
          file.puts text.to_json

          puts v.verse_key
        end
      end
    end

    def detect_colors
      COLOR_MAPPING.keys.each do |tafsir|
        COLORS_TO_CSS_CLASS_MAPPING[tafsir] = {}

        Dir["data/quranenc-tafsirs/#{tafsir}/*.json"].each do |f|
          begin
            text = JSON.parse(File.read(f)).first['tafsir']
            docs = Nokogiri::HTML::DocumentFragment.parse(text)
            docs.search("span").each do |span|
              style = span.attr("style")

              if style.present?
                if (color = Utils::CssStyle.parse(style)['color']).present?
                  COLORS_TO_CSS_CLASS_MAPPING[tafsir][color] = COLORS_TO_CSS_CLASS_MAPPING[tafsir][color].to_i + 1
                end
              end
            end
          rescue JSON::ParserError => e
            puts '========'
            puts e.message
            puts f
            puts "=-======"
          end
        end
      end

      File.open("data/quranenc-tafsirs/colors.json", "wb") do |file|
        file.puts COLORS_TO_CSS_CLASS_MAPPING.to_json
      end
    end

    def fetch_tafsir(key, verse)
      url = "https://quranenc.com/ar/ajax/tafsir/#{key}/#{verse.chapter_id}/#{verse.verse_number}"
      json = get_json(url)

      json['tafsir']
    rescue RestClient::NotFound
      log_message "#{key} Tafsir is missing for ayah #{verse.verse_key}. #{url}"
      {}
    end
  end
end