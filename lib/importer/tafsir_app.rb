# Usage
# importer = Importer::TafsirApp.new
# importer.import('tabari')
module Importer
  class TafsirApp < Base
    # TODO: https://tafsir.app/aliraab-almuyassar/2/37
    # https://tafsir.app/iraab-daas/2/33
    # https://tafsir.app/aljadwal/2/33
    # https://tafsir.app/aldur-almasoon/2/33
    # https://tafsir.app/lubab/2/33
    # https://tafsir.app/qiraat-almawsoah/2/33
    # https://tafsir.app/alnashir/2/33
    # https://tafsir.app/iraab-aldarweesh/2/33

    TAFISR_MAPPING = {
      'aliraab-almuyassar' => '',
      'iraab-daas' => '',
      'aljadwal' => '',
      'aldur-almasoon' => '',
      'lubab' => '',
      'qiraat-almawsoah' => '',
      'alnashir' => '',
      'iraab-aldarweesh' => '',
      'ibn-katheer' => 14,
      'tabari' => 15,
      'qurtubi' => 90,
      'baghawi' => 94,
      'muyassar' => 16,
      #'saadi' => 912, # probably won't use tafsir app for Saadi
      'almuyassar-ghareeb' => ''
    }

    def import(key)
      raise "Mapping is missing for #{key}" if TAFISR_MAPPING[key.to_s].blank?

      resource_content = ResourceContent.find(TAFISR_MAPPING[key.to_s])
      Draft::Tafsir.where(resource_content_id: resource_content.id).delete_all

      verses_imported = {}

      Verse.order('verse_index ASC').find_each do |verse|
        next if verses_imported[verse.id].present?

        result = fetch_tafsir(key, verse)
        tafsir = import_tafsir(verse, result, resource_content)
        tafsir.ayah_group_ids.each do |id|
          verses_imported[id] = true
        end
      end
    end

    protected

    def import_tafsir(verse, tafsir_json, resource_content)
      draft_tafsir = Draft::Tafsir
                       .where(
                         resource_content_id: resource_content.id,
                         verse_id: verse.id
                       ).first_or_initialize

      group_verses = find_ayah_group(verse, tafsir_json['ayahs_start'], tafsir_json['count'])
      source_text = tafsir_json['data']
      text = parse_tafsir(source_text)
      draft_tafsir.set_meta_value('source_data', { text: source_text })
      existing_tafsir = Tafsir.for_verse(verse, resource_content)

      draft_tafsir.tafsir_id = existing_tafsir&.id
      draft_tafsir.current_text = existing_tafsir&.text
      draft_tafsir.draft_text = text
      draft_tafsir.text_matched = existing_tafsir&.text == text

      draft_tafsir.verse_key = verse.verse_key

      draft_tafsir.group_verse_key_from = group_verses.first.verse_key
      draft_tafsir.group_verse_key_to = group_verses.last.verse_key
      draft_tafsir.group_verses_count = group_verses.size
      draft_tafsir.start_verse_id = group_verses.first.id
      draft_tafsir.end_verse_id = group_verses.last.id
      draft_tafsir.group_tafsir_id = verse.id

      draft_tafsir.save(validate: false)

      puts "#{verse.verse_key} - #{draft_tafsir.id}"
      draft_tafsir
    end

    def fetch_tafsir(key, verse)
      url = "https://tafsir.app/get.php?src=#{key}&s=#{verse.chapter_id}&a=#{verse.verse_number}&ver=1"
      data = get_json(url)

      data['count'] = 0 if data['count'].blank?
      data['ayahs_start'] = verse.verse_number if data['ayahs_start'].blank?

      data
    rescue RestClient::NotFound
      log_message "#{key} Tafsir is missing for ayah #{verse.verse_key}. #{url}"
      nil
    end

    def find_ayah_group(verse, start_ayah, count)
      Verse.where(
        chapter_id: verse.chapter_id, verse_number: start_ayah..(start_ayah + count)
      ).order('verse_index ASC')
    end

    def parse_tafsir(text)
      html = ""

      text.split("\n").each do |line|
        line.strip!
        next if line.empty?

        line.gsub!(/﴿(.*?)﴾/, '<span class="qpc-hafs">﴿\1﴾</span>')

        if line.start_with?('*')
          line.sub!('*', '').strip!
          html << "<h3>#{line}</h3>"
        else
          html << "<p>#{line}</p>"
        end
      end

      "<div class=ar lang=ar>#{html}</div>"
    end
  end
end