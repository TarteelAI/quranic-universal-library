namespace :ksu do
  task download_tajweed: :environment do
    1.upto(604) do |page|
      # http://mosshaf.com/ar/main?ver=1#?GetSura=1&vers=1&type=tagweed
      url = "https://mosshaf.com/ar/ajax/asbab?QuranSuraNo=1&QuranVerseNo=4&AsbabList=all&ShowNo=1"

      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient.get(url)
      end

      File.open("data/tajweed/#{page}.html", "wb") do |f|
        f << response.to_s
      end

      puts page
    end
  end

  desc "Download translation from Quran Complex site"
  task download: :environment do
    # Russian Saddi tafsir
    Verse.find_each do |v|
      next if File.exist?("data/ru_saddi/#{v.id}.html")

      ru_saddi = "http://quran.ksu.edu.sa/interface.php?ui=pc&do=tafsir&author=russian&sura=#{v.chapter_id}&aya=#{v.verse_number}"

      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient.get(ru_saddi)
      end

      File.open("data/ru_saddi/#{v.id}.html", "wb") do |f|
        f << response.to_s
      end

      puts "ru_saddi  #{v.id}"
    end

    # Indonasian tafsir
    Verse.find_each do |v|
      next if File.exist?("data/indonesian_jalalayn/#{v.id}.html")
      indonesian_jalalayn = "http://quran.ksu.edu.sa/interface.php?ui=pc&do=tafsir&author=indonesian&sura=#{v.chapter_id}&aya=#{v.verse_number}"

      response = with_rescue_retry([RestClient::Exceptions::ReadTimeout], retries: 3, raise_exception_on_limit: true) do
        RestClient.get(indonesian_jalalayn)
      end

      File.open("data/indonesian_jalalayn/#{v.id}.html", "wb") do |f|
        f << response.to_s
      end

      puts v.id
    end
  end

  task download_translation: :environment do
    # http://quran.ksu.edu.sa/interface.php?ui=pc&do=tarjama&tafsir=es_navio&b_sura=1&b_aya=1&e_sura=2&e_aya=1&11
    # http://quran.ksu.edu.sa/interface.php?ui=pc&do=tarjama&tafsir=ar_mu&b_sura=1&b_aya=1&e_sura=2&e_aya=1&11
    # http://quran.ksu.edu.sa/interface.php?ui=pc&do=tarjama&tafsir=ku_asan&b_sura=1&b_aya=1&e_sura=2&e_aya=1&11
    # http://quran.ksu.edu.sa/interface.php?ui=pc&do=tarjama&tafsir=sw_barwani&b_sura=1&b_aya=1&e_sura=2&e_aya=1&11
    [
      'es_navio',
      'sw_barwani', #49
      ''
    ]
  end

  task do_import: :environment do
    # Quran complex tafsirs
    # Indonesian - Tafsir Jalalayn
    # russian: русский (Russian) - Кулиев -ас-Саади (Russian (Russian) - Kuliev-as-Saadi)
    PaperTrail.enabled = false
    mapping = {
      ru_saddi: ResourceContent.find(170),
      indonesian_jalalayn: ResourceContent.find(816)
    }

    SANITIZER = Text::Sanitizer.new

    missing_ayahs = {
      ru_saddi: [],
      indonesian_jalalayn: []
    }

    issues = {
      ru_saddi: [],
      indonesian_jalalayn: []
    }

    mapping.each do |key, resource|
      Verse.find_each do |verse|
        content = File.read("data/#{key}/#{verse.id}.html")

        ayah, text = content.split('|||').map(&:strip)
        ayah = "<div class=qpc-hafs>#{ayah}</div>"

        if text.present?
          docs = Nokogiri::HTML::DocumentFragment.parse(text)
          translation = docs.search('.tafheem_trans').children.to_s

          if translation.present?
            translation = "<div lang='ru' class=translation>#{translation}</div>"
          else
            issues[key].push(verse.id)
          end

          tafsir = docs.search('.tafheem_comments').children.to_s

          unless tafsir.present?
            issues[key].push(verse.id)
          end

          text = SANITIZER.sanitize(tafsir).html

          content = "#{ayah}#{translation}#{text}"
          tafsir = Tafsir.where(verse_id: verse.id, resource_content_id: resource.id).first_or_initialize
          tafsir.text = content
          tafsir.language_name = resource.language_name
          tafsir.language_id = resource.language_id
          tafsir.chapter_id = verse.chapter_id
          tafsir.resource_name = resource.name
          tafsir.verse_key = verse.verse_key

          tafsir.verse_number = verse.verse_number
          tafsir.juz_number = verse.juz_number
          tafsir.hizb_number = verse.hizb_number
          tafsir.rub_el_hizb_number = verse.rub_el_hizb_number
          tafsir.page_number = verse.page_number
          tafsir.ruku_number = verse.ruku_number
          tafsir.surah_ruku_number = verse.surah_ruku_number
          tafsir.manzil_number = verse.manzil_number

          tafsir.save(validate: false)
          tafsir.group_verse_key_from =  verse.verse_key
          tafsir.group_verse_key_to =  verse.verse_key
          tafsir.group_verses_count = 1
          tafsir.group_tafsir_id = tafsir.id
          tafsir.start_verse_id = verse.id
          tafsir.end_verse_id = verse.id

          tafsir.save(validate: false)
        else
          missing_ayahs[key].push(verse.id)
        end
      end
    end
  end
end