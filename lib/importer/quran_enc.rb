# i = Importer::QuranEnc.new
# i.import 'dagbani_ghatubo'
module Importer
  class QuranEnc < Base
    include Utils::StrongMemoize

    REGEXP_REMOVE_FOOTNOTE = %r{<sup foot_note="?\d+"?>\d+</sup>[\d*\[\]]?}
    QURANENC_CHANGE_LOG_API = "https://quranenc.com/api/translations/versions"
    QURANENC_TRANSLATIONS_API = "https://quranenc.com/api/translations/"

    attr_reader :quran_enc_key, :issues

    def import_all
      TRANSLATIONS_MAPPING.each_key do |key|
        import key.to_s
      end
    end

    def get_change_log_for_key(quranenc_key)
      get_change_log.detect do |version|
        version['key'] == quranenc_key
      end
    end

    def get_change_log
      strong_memoize :quranenc_change_log do
        begin
          response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
            RestClient.get(QURANENC_CHANGE_LOG_API)
          end

          JSON.parse response.body
        rescue JSON::ParserError => e
          []
        end
      end
    end

    def get_translation_for_key(quranenc_key)
      get_translations.detect do |translation|
        translation['key'] == quranenc_key
      end
    end

    def get_translations
      strong_memoize :quranenc_translations do
        begin
          response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
            RestClient.get(QURANENC_TRANSLATIONS_API)
          end

          JSON.parse(response.body)['translations']
        rescue JSON::ParserError => e
          []
        end
      end
    end

    def import(translation_key, start_from: 1)
      @issues = []
      quran_enc_key = translation_key.to_s.strip

      if quran_enc_key.blank?
        log_message "no resource found with QuranEnc key: #{translation_key}"
        return
      end

      footnote_resource = nil
      has_footnotes = TRANSLATIONS_WITH_FOOTNOTES.include?(quran_enc_key)
      resource = find_or_create_resource(quran_enc_key)
      language = resource.language

      if has_footnotes
        footnote_resource = ResourceContent.where({
                                                    author_id: resource.author_id,
                                                    resource_type: 'content',
                                                    sub_type: 'footnote',
                                                    name: "#{resource.name} footnote",
                                                    description: "#{resource.name} footnotes",
                                                    cardinality_type: '1_ayah',
                                                    language_id: language.id,
                                                    language_name: language.name.downcase
                                                  }).first_or_initialize
        footnote_resource.save(validate: false)

        resource.set_meta_value('has-footnotes', true)
        Draft::FootNote.where(resource_content_id: footnote_resource.id).delete_all
      end

      chapters = Chapter.where('id >= ?', start_from).order('id ASC')

      chapters.each do |chapter|
        log_message "Importing Surah #{chapter.id} - #{chapter.name_simple} - #{quran_enc_key}"
        translations = fetch_translations_for_chapter(chapter, quran_enc_key)

        translations.each do |data|
          verse = Verse.find_by(verse_key: "#{data['sura']}:#{data['aya']}")

          if !has_footnotes && data['footnotes'].present?
            @issues.push({
                           tag: 'missing-footnote-mapping',
                           text: verse.verse_key
                         })
            log_message "!!!!!!!====== Wrong mapping for #{quran_enc_key}. This translation does have footnotes. See #{verse.verse_key}======!!!"
          end

          if data['translation'].blank?
            log_message "Text is missing for ayah #{verse.verse_key}"
          else
            import_verse(verse, resource, footnote_resource, language, quran_enc_key, data)
          end
        end
      end

      resource.set_meta_value('source', 'quranenc')

      if quranenc_translation = get_translation_for_key(translation_key)
        resource.set_meta_value("draft-quranenc-import-version", quranenc_translation['version'])
        resource.set_meta_value("draft-quranenc-import-timestamp", quranenc_translation['last_update'])
        resource.set_meta_value("draft-quranenc-import-date", Time.at(quranenc_translation['last_update']).strftime('%B %d, %Y at %I:%M %P %Z'))
      end

      resource.save

      if @issues.present?
        issues_group = @issues.group_by do |issue|
          issue[:tag]
        end

        issues_group.keys.each do |issue_tag|
          issue_description = issues_group[issue_tag].map do |issue|
            issue[:text]
          end

          AdminTodo.create(
            is_finished: false,
            tags: issue_tag,
            resource_content_id: resource.id,
            description: "#{quran_enc_key} parse issues in #{resource.name}(#{resource.id}). <div>#{issue_tag}</div>\n#{issue_description.uniq.join(', ')}"
          )
        end
      end
    end

    def report_new_translations
      document = get_html('https://quranenc.com/en/home#transes')
      translations = document.search("a[@href^='https://quranenc.com/en/browse/']").map do |link|
        link.attr('href').split('/').last
      end.reject { |t| t.include?('arabic') }

      translations - TRANSLATIONS_MAPPING.keys.map(&:to_s)
    end

    protected

    def import_verse(verse, resource, footnote_resource, _language, quran_enc_key, data)
      translation = if TRANSLATIONS_WITH_CUSTOM_PARSER.include?(quran_enc_key.to_s)
                      send("parse_#{quran_enc_key}", verse, resource, footnote_resource, quran_enc_key, data)
                    else
                      create_translation_with_footnote(verse, resource, footnote_resource, quran_enc_key, data)
                    end

      translation.save(validate: false)
    rescue Exception => e
      log_message "===== #{verse.verse_key} ERROR: #{e.message}"
      raise e
    end

    def fetch_translations_for_chapter(chapter, key)
      url = "https://quranenc.com/en/api/translation/sura/#{key}/#{chapter.id}"
      get_json(url)['result']
    rescue RestClient::NotFound
      puts "Translation is missing for surah #{chapter.id}. #{url}"
      []
    end

    def find_or_create_resource(quran_enc_key)
      mapping = TRANSLATIONS_MAPPING[quran_enc_key.to_sym]
      raise "mapping not found for translation #{quran_enc_key}. Please add the mapping and try again" if mapping.nil?

      resource = if mapping[:id]
                   ResourceContent.find(mapping[:id])
                 else
                   ResourceContent.where("meta_data ->> 'quranenc-key' = '#{quran_enc_key}'").first_or_initialize
                 end

      if resource.new_record?
        author_name = mapping[:name]
        language = resource.language || Language.find(mapping[:language])
        author = Author.where(name: author_name).first_or_create

        resource.cardinality_type = ResourceContent::CardinalityType::OneVerse
        resource.resource_type = ResourceContent::ResourceType::Content
        resource.sub_type = ResourceContent::SubType::Translation
        resource.set_meta_value('source', 'quranenc')
        resource.set_meta_value('quranenc-key', quran_enc_key)
        resource.data_source = data_source
        resource.language = language
        resource.language_name = language.name.downcase
        resource.author_name = author.name
        resource.name = author_name
        resource.approved = false
        resource.save(validate: false)
      end

      resource
    end

    def create_translation(verse, text, resource)
      draft_text = strip_ayah_number_from_start(text.strip, verse, resource)
      current_text = Translation.where(verse_id: verse.id, resource_content_id: resource.id).first&.text.to_s

      draft = Draft::Translation.where(
        verse: verse,
        resource_content: resource
      ).first_or_initialize

      draft.draft_text = simple_format(draft_text)
      draft.current_text = current_text

      draft
    end

    def create_foot_note(translation, resource, text, current_footnote)
      current_text = current_footnote&.text
      text = fix_encoding(text).sub(REGEXP_STRIP_TEXT[:general], '').strip
      draft_text = simple_format(text)

      Draft::FootNote.create(
        draft_text: draft_text,
        current_text: current_text,
        resource_content: resource,
        draft_translation: translation,
        text_matched: draft_text == current_text
      )
    end

    def create_translation_with_footnote(verse, resource, footnote_resource, quran_enc_key, data, report_foonote_issues: true)
      footnote_id_reg, footnote_text_reg = REGEXP_FOOTNOTES[quran_enc_key.to_sym]
      need_to_review = false

      translation = create_translation(verse, data['translation'], resource)

      if data['footnotes'].present?
        if report_foonote_issues && (footnote_id_reg.nil? || footnote_text_reg.nil?)
          need_to_review = true
          @issues.push({
                         tag: 'missing-footnote-mapping',
                         text: verse.verse_key
                       })

          puts "====FOOTNOTE REGEXP is missing for #{quran_enc_key} and #{verse.verse_key} has footnote"
        end

        translation.save(validate: false)
        translation_text = translation.draft_text
        footnotes_texts = data['footnotes'].to_s
        current_footnote_ids = translation.original_footnotes_ids

        footnote_ids = if footnote_id_reg
                         translation_text.scan(footnote_id_reg)
                       else
                         []
                       end

        footnotes_texts = if footnote_text_reg && footnote_ids.size > 1
                            parts = footnotes_texts.split(footnote_text_reg).select(&:present?)
                            need_to_review = parts.size != footnote_ids.size

                            parts
                          else
                            [footnotes_texts.to_s.strip.gsub(footnote_text_reg, '')]
                          end

        footnote_ids.each_with_index do |node, i|
          current_footnote = translation.original_footnote_text(current_footnote_ids[i])
          footnote = create_foot_note(translation, footnote_resource, footnotes_texts[i].to_s, current_footnote)

          translation_text.sub!(node.to_s, "<sup foot_note=#{footnote.id}>#{i + 1}</sup>")
        end

        # Add footnote text at the end
        if footnote_ids.blank?
          if report_foonote_issues
          need_to_review = true
          @issues.push({
                         tag: 'wrong-footnote-mapping',
                         text: verse.verse_key
                       })
          end

          footnotes_texts = footnotes_texts.join(' ')
          current_footnote = translation.original_footnote_text(current_footnote_ids[0])

          footnote = create_foot_note(translation, footnote_resource, footnotes_texts, current_footnote)
          translation_text = "#{translation_text} <sup foot_note=#{footnote.id}>1</sup>"
        end

        translation.draft_text = translation_text.sub(/\d+[.]/, '').strip
      end

      translation.need_review = need_to_review
      translation.text_matched = remove_footnote_tag(translation.current_text) == remove_footnote_tag(translation.draft_text)

      translation.save
      translation
    end

    def swahili_barawani(verse, resource, footnote_resource, quran_enc_key, data)
      # this translation has footnote, but there is no footnote markers in translaiton.
      # add footnote at end of ayah
      create_translation_with_footnote(verse, resource, footnote_resource, quran_enc_key, data, report_foonote_issues: false)
    end

    def parse_pashto_zakaria(verse, resource, footnote_resource, quran_enc_key, data)
      data['translation'] = data['translation'].sub(/\d+-\d+/, '')

      create_translation_with_footnote(verse, resource, footnote_resource, quran_enc_key, data)
    end

    def parse_kurdish_salahuddin(verse, resource, footnote_resource, quran_enc_key, data)
      # NOTE: This translation has embedded Arabic in the text,
      # Arabic is wrapped in square brackets [Arabic]
      # TODO: Should wrap Arabic text with span tag and use proper font to render it

      create_translation_with_footnote(verse, resource, footnote_resource, quran_enc_key, data)
    end

    def parse_bengali_zakaria(verse, resource, footnote_resource, quran_enc_key, data)
      # footnote numbers are in Bengali
      # First ayah of each surah has surah info in the footnotes, ignore this footnote
    end

    def parse_uyghur_saleh(verse, resource, _footnote_resource, _quran_enc_key, data)
      text = data['translation'].sub(/\[\d+\]/, '')
      create_translation(verse, text, resource)
    end

    def remove_footnote_tag(text)
      text.to_s.gsub(REGEXP_REMOVE_FOOTNOTE, '')
    end

    # Most translation of Quranenc has ayah number at the beginning of text
    def strip_ayah_number_from_start(text, verse, resource)
      reg = if REGEXP_STRIP_TEXT[resource.quran_enc_key.to_sym]
              Regexp.new format(REGEXP_STRIP_TEXT[resource.quran_enc_key.to_sym], ayah_num: verse.verse_number)
            else
              REGEXP_STRIP_TEXT[:general]
            end

      fix_encoding(text.sub(reg, '').strip)
    end

    def data_source
      strong_memoize :data_source do
        DataSource.find_or_create_by(name: 'Quranenc', url: 'https://quranenc.com')
      end
    end

    REGEXP_STRIP_TEXT = {
      spanish_mokhtasar: '^(\d*,)?\d+.(\s)?', # 2:3-4
      #TODO: refactor general regexp
      general: /^(?:\[\d+(?::\d+)?(?:-\d+)?\]|\(\d+(?::\d+)?(?:-\d+)?\)|\d+(?::\d+)?(?:-\d+)?[\)\]\*.]*)/
    }.freeze

    TRANSLATIONS_WITH_CUSTOM_PARSER = %w[
      uyghur_saleh
      pashto_zakaria
      kurdish_salahuddin
      bengali_zakaria
    ].freeze

    REGEXP_FOOTNOTES = {
      pashto_rwwad: [/\[\d+\]/, /\[\d+\]/],
      ikirundi_gehiti: [/\[\d+\]/, /\[\d+\]/],
      albanian_nahi: [/\[\d+\]/, /\[\d+\]/],
      indonesian_sabiq: [/\*+\(\d+\)/, /\*+\d+\)./],
      portuguese_nasr: [/\(\d+\)/, /\(\d+\)./],
      tajik_khawaja: [/\(\d+\)/, /\d+[.]/],
      spanish_montada_eu: [/\[\d+\]/, /\[\d+\]/],
      indonesian_complex: [/\d+/, /\d+[.\s]/],
      indonesian_affairs: [/\d+\)/, /\*\d+\)/],
      french_montada: [/\[\d+\]/, /\[\d+\]/],
      english_hilali_khan: [/\[\d+\]/, /\[\d+\]/],
      english_saheeh: [/\[\d+\]/, /\[\d+\]-/],
      hausa_gummi: [/\*+/, /\*+/],
      hindi_omari: [/\[\d+\]/, /\d+./],
      urdu_junagarhi: [/\(\d+\)/, /(\n)?\(\d+\)/], # OLD [/\*+/, /\*+/],
      spanish_montada_latin: [/\[\d+\]/, /\[\d+\]/],
      kinyarwanda_assoc: [/\[\d+\]/, /\[\d+\]/],
      english_waleed: [/\[\d+\]/, /\[\d+\]/],
      french_rashid: [/\[\d+\]/, /\[\d+\]/],
      romanian_assoc: [/\(\d+\)/, /\(\d+\)/],
      somali_yacob: [/\d+/, /\d+/],
      macedonian_group: [/\[\d+\]/, /\(\d+:\d+\)/],
      swahili_barawani: [], # No footnotes number
      dagbani_ghatubo: [/\[\d+\]/, /\[\d+\]/],
      yaw_silika: [/\[\d+\]/, /\(\d+:\d+\)/],
      georgian_rwwad: [/\*+/, /\*+/],
      french_hameedullah: [/\[\s*\d+\]/, /\[\d+\]/],
      vietnamese_rwwad: [/\(\d+\)/, /\(\d+\)/],
      uzbek_mansour: [],
      uzbek_sadiq: [],
      yoruba_mikail: [],
      spanish_garcia: [/\[\d+\]/, /\[\d+\]/],
      tamil_omar: [/\*+/, /\*+/],
      lithuanian_rwwad: [/\[\d+\]/, /\[\d+\]/],
      telugu_muhammad: [/\([a-z]\)/, /\([a-z]\)/],
      chichewa_betala: [/\[\d+\]/, /\[\d+\]/],
      punjabi_arif: [/\d+/, /\d+/],
      lingala_zakaria: [/\(\d+\)/, /\d+/],
      kyrgyz_hakimov: [/\*+/, /\*+/],
      moore_rwwad: [/\[\d+\]/, /\[\d+\]/],
      kannada_hamza: [/\[\d+\]/, /\[\d+\]/]
    }.freeze

    TRANSLATIONS_MAPPING = {
      dutch_center: {language: 118, name: 'Dutch Islamic Center', id: 942},
      pashto_rwwad: {language: 132, name: 'Rowwad Translation Center', id: 943},
      kannada_hamza: {language: 85, name: 'Muhammad Hamza Battur', id: 944},
      ikirundi_gehiti: {language: 136, name: 'Ikirundi gehiti', id: 945},
      moore_rwwad: {language: 194, name: 'Moore rwwad', id: 1173},
      chinese_suliman: { language: 185, name: 'Muhammad Sulaiman', id: 853 },
      albanian_nahi: { language: 187, name: 'Hasan Efendi Nahi', id: 88 },
      amharic_sadiq: { language: 6, name: 'Sadiq and Sani', id: 87 },
      assamese_rafeeq: { language: 10, name: 'Shaykh Rafeequl Islam Habibur-Rahman', id: 120 },
      bosnian_korkut: { language: 23, name: 'Besim Korkut', id: 126 },
      bosnian_mihanovich: { language: 23, name: 'Muhamed Mehanović', id: 25 },
      chinese_makin: { language: 185, name: 'Muhammad Makin', id: 109 },
      english_saheeh: { language: 38, name: 'Saheeh International', id: 20 },
      french_montada: { language: 49, name: 'Montada Islamic Foundation', id: 136 },
      german_bubenheim: { language: 33, name: 'Frank Bubenheim and Nadeem', id: 27 },
      hausa_gummi: { language: 58, name: 'Abubakar Mahmood Jummi', id: 115 },
      hindi_omari: { language: 60, name: 'Maulana Azizul Haque al-Umari', id: 122 },
      indonesian_affairs: { language: 67, name: 'Indonesian Islamic affairs ministry', id: 33 },
      indonesian_complex: { language: 67, name: 'King Fahad Quran Complex', id: 134 },
      japanese_meta: { language: 76, name: 'Ryoichi Mita', id: 35 },
      kazakh_altai_assoc: { language: 82, name: 'Khalifah Altai', id: 113 },
      khmer_cambodia: { language: 84, name: 'Cambodian Muslim Community Development', id: 128 },
      oromo_ababor: { language: 126, name: 'Ghali Apapur Apaghuna', id: 111 },
      pashto_zakaria: { language: 132, name: 'Zakaria Abulsalam', id: 118 },
      portuguese_nasr: { language: 133, name: 'Helmi Nasr', id: 103 },
      turkish_shaban: { language: 167, name: 'Shaban Britch', id: 112 },
      turkish_shahin: { language: 167, name: 'Muslim Shahin', id: 124 },
      urdu_junagarhi: { language: 174, name: 'Maulana Muhammad Junagarhi', id: 54 },
      uzbek_mansour: { language: 175, name: 'Alauddin Mansour', id: 101 },
      uzbek_sadiq: { language: 175, name: 'Muhammad Sodik Muhammad Yusuf', id: 55 },
      yoruba_mikail: { language: 183, name: 'Shaykh Abu Rahimah Mikael Aykyuni', id: 125 },
      french_hameedullah: { language: 49, name: 'Muhammad Hamidullah', id: 31 },
      nepali_central: { language: 116, name: 'Ahl Al-Hadith Central Society of Nepal', id: 108 },
      persian_ih: { language: 43, name: 'IslamHouse', id: 135 },
      persian_tagi: { language: 43, name: 'Dr. Husein Tagy Klu Dary', id: 29 },
      spanish_garcia: { language: 40, name: 'Muhammad Isa Garcia', id: 83 },
      spanish_montada_eu: { language: 40, name: 'Montada Islamic Foundation', id: 140 },
      spanish_montada_latin: { language: 40, name: 'Noor International Center' },
      tajik_khawaja: { language: 160, name: 'Khawaja Mirof & Khawaja Mir', id: 139 },
      tamil_baqavi: { language: 158, name: 'Abdul Hameed Baqavi', id: 133 },

      uyghur_saleh: { language: 172, name: 'Shaykh Muhammad Saleh', id: 76 },
      kurdish_bamoki: { language: 89, name: 'Muhammad Saleh Bamoki', id: 143 },
      azeri_musayev: { language: 13, name: 'Khan Mosaiv', id: 75 },
      somali_abduh: { language: 150, name: 'Muhammad Ahmad Abdi', id: 46 },
      english_hilali_khan: { language: 38, name: 'Muhammad Taqi-ud-Din al-Hilali & Muhammad Muhsin Khan', id: 203 },
      indonesian_sabiq: { language: 67, name: 'The Sabiq company', id: 141 },
      english_rwwad: { language: 38, name: 'Ruwwad Center', id: 206 },
      english_irving: { language: 38, name: 'Dr. T. B. Irving', id: 207 },
      german_aburida: { language: 33, name: 'Abu Reda Muhammad ibn Ahmad', id: 208 },
      italian_rwwad: { language: 74, name: 'Othman al-Sharif', id: 209 },
      turkish_rwwad: { language: 167, name: 'Dar Al-Salam Center', id: 210 },
      tagalog_rwwad: { language: 164, name: 'Dar Al-Salam Center', id: 211 },

      # only first 6 surah are available
      georgian_rwwad: { language: 78, name: 'Ruwwad Center' },
      # disable this, has some missing ayah(3:154)
      albanian_rwwad: { language: 187, name: 'Ruwwad Center', id: 216 },

      bengali_zakaria: { language: 20, name: 'Dr. Abu Bakr Muhammad Zakaria', id: 213 },
      bosnian_rwwad: { language: 23, name: 'Dar Al-Salam Center', id: 214 },
      serbian_rwwad: { language: 152, name: 'Dar Al-Salam Center', id: 215 },
      ukrainian_yakubovych: { language: 173, name: 'Dr. Mikhailo Yaqubovic', id: 217 },
      japanese_saeedsato: { language: 76, name: 'Saeed Sato', id: 218 },
      korean_hamid: { language: 86, name: 'Hamed Choi', id: 219 },
      vietnamese_rwwad: { language: 177, name: 'Ruwwad Center', id: 220 },
      vietnamese_hassan: { language: 177, name: 'Hasan Abdul-Karim', id: 221 },
      kazakh_altai: { language: 82, name: 'Khalifa Altay', id: 222 },
      tajik_arifi: { language: 160, name: 'Pioneers of Translation Center', id: 223 },
      malayalam_kunhi: { language: 106, name: 'Abdul-Hamid Haidar & Kanhi Muhammad', id: 224 },
      gujarati_omari: { language: 56, name: 'Rabila Al-Umry', id: 225 },
      marathi_ansari: { language: 108, name: 'Muhammad Shafi’i Ansari', id: 226 },
      telugu_muhammad: { language: 159, name: 'Maulana Abder-Rahim ibn Muhammad', id: 227 },
      sinhalese_mahir: { language: 145, name: 'Ruwwad Center', id: 228 },
      tamil_omar: { language: 158, name: 'Sheikh Omar Sharif bin Abdul Salam', id: 229 },
      thai_complex: { language: 161, name: 'Society of Institutes and Universities', id: 230 },
      swahili_abubakr: { language: 157, name: 'Dr. Abdullah Muhammad Abu Bakr and Sheikh Nasir Khamis', id: 231 },
      luganda_foundation: { language: 95, name: 'African Development Foundation', id: 232 },
      hebrew_darussalam: { language: 59, name: 'Dar Al-Salam Center', id: 233 },
      kinyarwanda_assoc: { language: 139, name: 'The Rwanda Muslims Association team', id: 774 },
      english_waleed: { language: 38, name: 'Dr. Waleed Bleyhesh Omary', id: 777 },
      french_rashid: { language: 49, name: 'Rashid Maash', id: 779 },
      bulgarian_translation: { language: 16, name: 'Bulgarian Translation', id: 781 },
      romanian_assoc: { language: 137, name: 'Islamic and Cultural League', id: 782 },
      malay_basumayyah: { language: 110, name: 'Abdullah Basamia', id: 784 },
      dari_badkhashani: { language: 190, name: 'Mawlawi Muhammad Anwar Badkhashani', id: 785 },
      somali_yacob: { language: 150, name: 'Abdullah Hassan Yacoub', id: 786 }, # عبدالله حسن يعقوب
      macedonian_group: { language: 105, name: 'Macedonian scholars', id: 788 },
      swahili_barawani: { language: 157, name: 'Muhsen Alberwany', id: 793 },
      ankobambara_foudi: { language: 19, name: 'Suliman Kanti', id: 795 },
      ankobambara_dayyan: { language: 19, name: 'Baba Mamady Jani', id: 796 },

      chichewa_betala: { id: 797, language: 123, name: 'Khaled Ibrahim Betala' },
      dagbani_ghatubo: {  id: 927, language: 191, name: 'Muhammad Baba Gutubu' },
      yaw_silika: { language: 192, name: 'Abdul Hamid Silika', id: 799 },
      fulani_rwwad: { id: 800, language: 44, name: 'Rowad Translation Center' },
      asante_harun: { language: 170, name: 'Rowad Translation Center', id: 801 },
      kurdish_salahuddin: { language: 89, name: 'Salahuddin Abdulkarim' }, # This one has embeded Arabic
      uzbek_rwwad: { language: 175, name: 'Rowwad Translation Center', id: 868 },
      korean_rwwad: { language: 86, name: 'Rowad Translation Center' },
      kurmanji_ismail: { language: 89, name: 'Dr. Ismail Sigerey' },
      lithuanian_rwwad: { id: 904, language: 99 },
      kyrgyz_hakimov: { id: 858 },
      punjabi_arif: { id: 857 },
      lingala_zakaria: { id: 855, name: 'Zakariya Muhammed Balingongo' },
      afar_hamza: { id: 854, name: 'Shaikh Mahmud Abdulkader Hamza' }
    }.freeze

    TRANSLATIONS_WITH_FOOTNOTES = [
      'dutch_center',
      'pashto_rwwad',
      'kannada_hamza',
      'ikirundi_gehiti',
      'moore_rwwad',
      'tamil_omar',
      'spanish_garcia',
      'kyrgyz_hakimov',
      'lingala_zakaria',#some footnotes has issues 4/163
      'punjabi_arif',
      'lithuanian_rwwad',
      'chichewa_betala',
      'telugu_muhammad',
      'albanian_nahi',
      'english_hilali_khan',
      'english_saheeh',
      'hausa_gummi',
      'hindi_omari',
      'indonesian_sabiq',
      'portuguese_nasr',
      'uzbek_mansour',
      'uzbek_sadiq',
      'yoruba_mikail',
      'french_montada',
      'indonesian_affairs',
      'indonesian_complex',
      'spanish_garcia',
      'spanish_montada_eu',
      'tajik_khawaja',
      'spanish_montada_latin',
      'kinyarwanda_assoc',
      'french_rashid',
      'english_waleed',
      'romanian_assoc',
      'somali_yacob',
      'macedonian_group',
      'swahili_barawani',
      'dagbani_ghatubo',
      'yaw_silika',
      'assamese_rafeeq',
      'georgian_rwwad',
      'french_hameedullah',
      'vietnamese_rwwad',
      # Custom
      'uyghur_saleh',
      'pashto_zakaria',
      'bengali_zakaria',
      'urdu_junagarhi'
    ].freeze
  end
end


