# qortobi: https://quran.ksu.edu.sa/tafseer/qortobi-saadi/sura2-aya1.html

module Importer
  class QuranEncTafsir < QuranEnc
    REGEXP_STRIP_TEXT = {
      general: /^[\[\(]*(\d+[\s-]*[\d]*)[\]\)\s.-]*/
    }

    COLORS_TO_CSS_CLASS_MAPPING = {}

    COLOR_MAPPING = {
      15 => {
        # tabary
        '008000': 'arabic qpc-hafs green', # Lime green
        '950000': 'red', # Burgundy, usually name of sahabi, surah
        '006d98': 'blue', # teal blue, usually quote (qala)
        '947721': 'arabic qpc-hafs brown',
        '707070': 'reference'
      },
      14 => {
        # katheer
        '008000': 'arabic qpc-hafs',
        '006d98': 'blue', # teal blue
        '950000': 'red',
        '707070': 'reference brown'
      },
      94 => {
        # baghawy
        '008000': 'green', # reference if there is number in text, otherwise arabic
        '950000': 'arabic qpc-hafs',
        '947721': 'arabic qpc-hafs',
        '006d98': 'blue',
        "707070": 'reference'
      },
      91 => {
        # saadi
        '006d98': 'blue',
        '947721': 'arabic qpc-hafs brown',
        '950000': 'red',
        '707070': 'arabic qpc-hafs',
        '008000': 'arabic qpc-hafs green'
      },
      16 => {
        # moyassar
        "006d98": 'blue',
        "6c6c00": 'brown',
        '950000': 'red',
        '008000': 'green',
        '947721': 'arabic qpc-hafs brown'
      }
    }

    TAFSIR_MAPPING = {
      moyassar: { id: 16 },
      # Arabic saadi: { id: 91 }, Using https://saadi.islamenc.com now
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
        id: 1283,
        name: 'Uzbek mokhtasar',
        language: ''
      },
      uyghur_mokhtasar: {
        id: 1282,
      },
      thai_mokhtasar: {
        id: 1281
      },
      telugu_mokhtasar: {
        id: 1280
      },
      tamil_mokhtasar: {
        id: 1279
      },
      serbian_mokhtasar: {
        id: 1278
      },
      sinhalese_mokhtasar: {
        id: 1277
      },
      pashto_mokhtasar: {
        id: 1276
      },
      kyrgyz_mokhtasar: {
        id: 1275
      },
      kurdish_mokhtasar: {
        id: 1274
      },
      hindi_mokhtasar: {
        id: 1273
      },
      fulani_mokhtasar: {
        id: 1272
      },
      azeri_mokhtasar: {
        id: 1271
      }
    }

    attr_reader :resource_content

    def import_all
      TAFSIR_MAPPING.keys.each do |key|
        import(key)
      end
    end

    def import(quran_enc_key)
      @resource_content = find_or_create_resource(quran_enc_key)
      Draft::Tafsir.where(resource_content_id: @resource_content.id).delete_all

      Verse.order('id ASC').each do |verse|
        content = fetch_tafsir(quran_enc_key, verse)
        import_tafsir(verse, content) if content.present?
      end

      resource_content.run_draft_import_hooks
    end

    def download(quran_enc_key)
      resource = find_or_create_resource(quran_enc_key)
      raise "Resource Content is not configured for #{quran_enc_key}" if resource.blank?

      FileUtils.mkdir_p("data/quranenc-tafsirs/#{quran_enc_key}")

      1.upto(114).each do |c|
        download_chapter(c, quran_enc_key)
      end
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
        language = resource.language || Language.find(mapping[:language])
        data_source = DataSource.find_or_create_by(name: 'Quranenc', url: 'https://quranenc.com')

        author_name = mapping[:author]
        author = Author.where(name: author_name).first_or_create if author_name.present?

        resource.set_meta_value('source', 'quranenc')
        resource.set_meta_value('quranenc-key', quran_enc_key)
        resource.data_source = data_source
        resource.language = language
        resource.language_name = language.name.downcase
        resource.author_name = author&.name
        resource.name = resource.name || mapping[:name]
        resource.resource_info = resource.resource_info.presence || mapping[:info]
      end

      resource.cardinality_type = ResourceContent::CardinalityType::NVerse
      resource.resource_type = ResourceContent::ResourceType::Content
      resource.sub_type = ResourceContent::SubType::Tafsir
      resource.save(validate: false)

      resource
    end

    def sanitize_text(text)
      if color_mapping = COLOR_MAPPING[resource_content.id]
        text = text.gsub(REGEXP_STRIP_TEXT[:general], '').strip
        TAFSIR_SANITIZER.sanitize(
          text,
          color_mapping: color_mapping,
          resource_language: resource_content.language.iso_code
        ).html
      else
        clean_up_text(text, resource_content)
      end
    end

    def download_chapter(chapter_id, quran_enc_key)
      Verse.where(chapter_id: chapter_id).order('verse_number asc').each do |v|
        next if File.exist?("data/quranenc-tafsirs/#{quran_enc_key}/#{v.verse_key}.json")

        File.open("data/quranenc-tafsirs/#{quran_enc_key}/#{v.verse_key}.json", "wb") do |file|
          text = fetch_tafsir(quran_enc_key, v)
          file.puts(text.to_json) if text.present?

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
      return fetch_mokhtasar_tafsir(key, verse) if key.to_s.include?('mokhtasar')

      key = TAFSIR_MAPPING[key.to_sym][:key] || key

      url = "https://quranenc.com/ar/ajax/tafsir/#{key}/#{verse.chapter_id}/#{verse.verse_number}"
      json = get_json(url)

      content = json['tafsir'][0]
      content['tafsir']
    rescue RestClient::NotFound
      log_message "#{key} Tafsir is missing for ayah #{verse.verse_key}. #{url}"
      nil
    end

    def fetch_mokhtasar_tafsir(key, verse)
      url = "https://quranenc.com/api/v1/translation/aya/#{key}/#{verse.chapter_id}/#{verse.verse_number}"
      json = get_json(url)

      json['result']['translation']
    rescue RestClient::NotFound
      log_message "#{key} Tafsir is missing for ayah #{verse.verse_key}. #{url}"
      nil
    rescue Exception => e
      nil
    end

    def import_tafsir(verse, text)
      draft_tafsir = Draft::Tafsir
                       .where(
                         resource_content_id: resource_content.id,
                         verse_id: verse.id
                       ).first_or_initialize

      draft_tafsir.set_meta_value('source_data', { text: text })
      existing_tafsir = Tafsir.for_verse(verse, resource_content)

      draft_tafsir.tafsir_id = existing_tafsir&.id
      draft_tafsir.current_text = existing_tafsir&.text
      draft_tafsir.draft_text = sanitize_text(text)
      draft_tafsir.text_matched = existing_tafsir&.text == text

      draft_tafsir.verse_key = verse.verse_key

      draft_tafsir.group_verse_key_from = verse.verse_key
      draft_tafsir.group_verse_key_to = verse.verse_key
      draft_tafsir.group_verses_count = 1
      draft_tafsir.start_verse_id = verse.id
      draft_tafsir.end_verse_id = verse.id
      draft_tafsir.group_tafsir_id = verse.id

      draft_tafsir.save(validate: false)

      puts "#{verse.verse_key} - #{draft_tafsir.id}"
    end
  end
end