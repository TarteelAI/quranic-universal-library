# https://www.elastic.co/guide/en/elasticsearch/reference/7.3/analysis-synonym-tokenfilter.html
#

namespace :es_synonyms do
  task export: :environment do
    require 'fileutils'
    FileUtils::mkdir_p 'public/assets'

    file_name = 'public/assets/quran_word_synonym.txt'

    File.open file_name, 'wb' do |file|
      Synonym.find_each do |s|
        synonyms = [s.text] + s.approved_synonyms
        clean = synonyms.map {|s| s.strip.remove_dialectic}.uniq.select do |s|
          s.length > 2
        end

        file.puts "#{clean.join(', ')}"
      end
    end

    puts "done #{file_name}"
  end

  task generate: :environment do
    WordSynonym.delete_all
    Synonym.delete_all

    HAFS_WAQF = ["ـ", "ۖ", "ۗ", "ۘ", "ۚ", "ۛ", "ۜ", "۞", "ۢ", "ۦ", "ۧ", "ۨ", "۩", "۪", "۬", "ۭ"]
    INDOPAK_WAQF = ["ۛ", "ٚ", "ؔ", "ؕ", "ۥ", "ۚ", "۪", "۠", "ۙ", "ؗ", "۫", "ۘ", "ۗ", "۬", "ۙ", "۬", "ۦ"]
    EXTRA_CHARS = ['', '', '', '', '‏', ',', '‏', '​', '', '‏', "\u200f"]
    WAQF_REG = Regexp.new((HAFS_WAQF + INDOPAK_WAQF + EXTRA_CHARS).join('|'))

    def normalize(str)
      str = str.tr("ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđḍÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšȘșſŢţŤťŦŧȚțÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž", "AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDddEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSsSssTtTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz  ")
      str.tr("'ʿ", '').downcase
    end

    def remove_waqf_sign(text)
      text.gsub(WAQF_REG, '').strip
    end

    uniq_words = {}
    Word.unscoped.includes(:lemma, :stem).order('verse_id asc, position asc').each do |word|
      next if 'word' != word.char_type_name
      lemma = word.lemma
      stem = word.stem

      lemmas = [lemma&.text_clean, lemma&.text_madani, stem&.text_clean, stem&.text_madani]
      scripts = [word.text_imlaei, word.text_indopak, word.text_uthmani, word.text_uthmani_simple, word.text_imlaei_simple, word.text_qpc_hafs].uniq.map do |s|
        remove_waqf_sign s
      end

      transliteration = word.en_transliteration

      synonyms = lemmas + scripts + [transliteration, normalize(transliteration)]

      all = synonyms.flatten.compact_blank.map do |text|
        [text.to_s.remove_dialectic, text]
      end.flatten.uniq

      key = word.text_uthmani.to_s.remove_dialectic
      uniq_words[key] ||= {}
      uniq_words[key][word.id] = all
      puts word.location
    end

    file_name = 'public/assets/quran_word_synonym.txt'
    info_file = 'public/assets/quran_word_synonym_info.txt'
    require 'fileutils'
    FileUtils::mkdir_p 'public/assets'

    File.open file_name, 'wb' do |file|
      uniq_words.each do |key, val|
        all_synonyms = val.values.flatten.uniq
        synonym = Synonym.where(text: key).first_or_create
        synonym.update(synonyms: all_synonyms)

        val.keys.each do |w|
          WordSynonym.where(word_id: w, synonym_id: synonym.id).first_or_create
        end

        file << "#{all_synonyms.join(', ')}\n"
      end
    end

    File.open info_file, 'wb' do |file|
      uniq_words.each do |key, val|
        file << "#{val}\n"
      end
    end

    puts "done #{file_name}"
  end

  task prepare_with_transliterations: :environment do
    script = ["text_uthmani",
              "text_indopak",
              "text_imlaei_simple",
              "text_imlaei",
              "text_uthmani_simple",
              "text_qpc_hafs",
              "text_indopak_nastaleeq",
              "text_qpc_nastaleeq",
              "text_qpc_nastaleeq_hafs"]

    uniq_words_mapping = {}
    # strip hizb, sajdah signs etc
    def clean_text(text)
      text.gsub(/۞|۩|/, '').strip
    end

    def find_word(text, uniq_words_mapping)
      if uniq_words_mapping[text]
        return { text => uniq_words_mapping[text] }
      end

      if uniq_words_mapping[text.remove_dialectic]
        return { text => uniq_words_mapping[text.remove_dialectic] }
      end

      uniq_words_mapping.each do |key, value|
        # ignore tatweel
        text_without_tatweel = value[:texts].map do |a|
          a.gsub('ـ', '')
        end

        without_dialectic = value[:texts].map(&:remove_dialectic)

        if key.gsub('ـ', '') == text || value[:texts].include?(text) || text_without_tatweel.include?(text) || without_dialectic.include?(text) || without_dialectic.include?(text.remove_dialectic)
          return { key => value }
        end
      end

      return nil
    end

    Word.words.each do |word|
      key = clean_text(word.text_imlaei_simple)
      uniq_words_mapping[key] ||= {
        word_ids: [],
        texts: []
      }

      uniq_words_mapping[key][:word_ids].push(word.id)
      word_scripts = script.map do |attr|
        clean_text word.send(attr)
      end.uniq

      lemma = word.lemma
      word_scripts += [lemma&.text_madani, lemma&.text_clean]

      uniq_words_mapping[key][:texts].concat word_scripts
    end

    uniq_words_mapping.keys.each do |key|
      uniq_words_mapping[key] = {
        word_ids: uniq_words_mapping[key][:word_ids].uniq,
        texts: uniq_words_mapping[key][:texts].compact_blank.uniq
      }
    end

    # Starting parsing the transliterations xml
    xml_data = File.read("data/arabic-words-transliterations.xml")
    require 'nokogiri'
    doc = Nokogiri::XML(xml_data)
    synonyms_data = {}
    missing = []

    doc.xpath('//word').each do |word|
      arabic_simple = word.at_xpath('./arabic_simple').text
      arabic_uthmani = word.at_xpath('./arabic_uthmani').text
      transliterations = word.at_xpath('./transliterations').text.split(' ')

      puts "Parsing #{arabic_simple}"

      word = find_word(arabic_simple, uniq_words_mapping) || find_word(arabic_simple.remove_dialectic, uniq_words_mapping) || find_word(arabic_uthmani, uniq_words_mapping) || find_word(arabic_uthmani.remove_dialectic, uniq_words_mapping)

      if word
        k = word.keys.first
        mapping = word.values.first

        synonyms_data[k] ||= {
          word_ids: [],
          texts: []
        }

        synonyms_data[k][:word_ids].concat mapping[:word_ids]
        synonyms_data[k][:texts].concat(mapping[:texts])
        synonyms_data[k][:texts].concat(transliterations)
        synonyms_data[k][:texts].concat([arabic_simple, arabic_uthmani])
      else
        missing.push(arabic_simple)

        synonyms_data[arabic_simple] ||= {
          word_ids: [],
          texts: [arabic_simple, arabic_uthmani] + transliterations
        }
      end
    end

    extra_keys_in_uniq_words = []
    # Reports
    unmapped_keys = (uniq_words_mapping.keys - synonyms_data.keys)
    unmapped_keys.each do |key|
      unless synonyms_data[key].present? || uniq_words_mapping[key][:texts].include?(key)
        extra_keys_in_uniq_words.push key
      end
    end

    # last cleanup, remove duplictes
    synonyms_data.keys.each do |key|
      synonyms_data[key] = {
        word_ids: synonyms_data[key][:word_ids].uniq,
        texts: synonyms_data[key][:texts].compact_blank.uniq
      }
    end
    # Export the results
    File.open("quran_words_synonum.json", "wb") do |file|
      file.puts synonyms_data.as_json
    end

    WordSynonym.delete_all
    Synonym.delete_all

    synonyms_data.each do |key, val|
      all_synonyms = val[:texts]
      synonym = Synonym.where(text: key).first_or_create
      synonym.update(synonyms: all_synonyms)

      val[:word_ids].each do |w|
        WordSynonym.where(word_id: w, synonym_id: synonym.id).first_or_create
      end
    end

    Synonym.find_each do |s|
      s.update approved_synonyms: s.synonyms.map(&:remove_dialectic).uniq
    end
  end
end