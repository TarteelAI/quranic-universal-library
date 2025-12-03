# Usage
# importer = Importer::TafsirApp.new
# importer.import('iraab-graphs')
# Importer::TafsirApp.delay.import_tafsirs(['alaloosi'])

#
module Importer
  class TafsirApp < Base
    TAFISR_MAPPING = {
      'aliraab-almuyassar' => 1477,
      'iraab-daas' => 1478,
      'aljadwal' => 1479,
      'aldur-almasoon' => 1480,
      'lubab' => 1481,
      'qiraat-almawsoah' => 1482,
      'alnashir' => 1483,
      'iraab-aldarweesh' => 1484,
      'ibn-katheer' => 14,
      'tabari' => 15,
      'qurtubi' => 90,
      'ibn-aashoor' => 92, # TODO: fix poetry see 2:3
      'baghawi' => 94,
      'muyassar' => 16,
      'almuyassar-ghareeb' => 1517,
      'aysar-altafasir' => 1475,
      'tadabbur-wa-amal' => 1476,
      'ibn-uthaymeen' => 1485,
      'jalalayn' => 1486,
      'albaydawee' => 1487,
      'iejee' => 1488,
      'alnasafi' => 1489,
      'alwajeez' => 1490,
      'zimneen' => 1491,
      'mathoor' => 1492,
      'ibn-abi-hatim' => 1493,
      'aldur-almanthoor' => 1494,
      'fath-albayan' => 1495,
      'fath-alqadeer' => 1496,
      'altasheel' => 1497,
      'alaloosi' => 1498,
      'alrazi' => 1499, # Fix page sep see 2:3
      'adwaa-albayan' => 1500,
      'nathm-aldurar' => 1501,
      'ibn-atiyah' => 1502,
      'albahr-almuheet' => 1503,
      'albaseet' => 1504,
      'abu-alsuod' => 1505,
      'kashaf' => 1506,
      'zad-almaseer' => 1507,
      'almawirdee' => 1508,
      'ibn-alqayyim' => 1509,
      #'ibn-taymiyyah' => 1510 # Need to OCR this
      'samaani' => 1511,
      'makki' => 1512,
      'mahasin-altaweel' => 1513,
      'althaalabi' => 1514,
      'samarqandi' => 1515,
      'althalabi' => 1516,
      'ayah-morph' => 1518,
      'iraab-graphs' => 1573,
      'wahidi-asbab' => 1575,
    }

    def self.import_tafsirs(keys)
      keys.each do |key|
        importer = Importer::TafsirApp.new
        importer.import(key)
      end
    end

    def import(key)
      raise "Mapping is missing for #{key}" if TAFISR_MAPPING[key.to_s].blank?

      resource_content = ResourceContent.find(TAFISR_MAPPING[key.to_s])
      Draft::Tafsir.where(resource_content_id: resource_content.id).delete_all

      verses_imported = {}

      Verse.order('verse_index ASC').find_each do |verse|
        next if verses_imported[verse.id].present?

        result = fetch_tafsir(key, verse)

        if tafsir = import_tafsir(verse, result, resource_content)
          tafsir.ayah_group_ids.each do |id|
            verses_imported[id] = true
          end
        else
          log_issue({tag: 'missing-tafsir', text: verse.verse_key })
        end
      end

      run_after_import_hooks(resource_content)
    end

    protected


    def import_tafsir(verse, tafsir_json, resource_content)
      draft_tafsir = Draft::Tafsir
                       .where(
                         resource_content_id: resource_content.id,
                         verse_id: verse.id
                       ).first_or_initialize

      group_verses = find_ayah_group(verse, tafsir_json['ayahs_start'], tafsir_json['count'])
      source_text = tafsir_json['data'].to_s.strip

      if source_text.present?
        if resource_content.tafsir_app_key == 'iraab-graphs'
          text = source_text
        else
          text = sanitize_text(source_text)
        end

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
      else
        log_message "Tafsir is missing for ayah #{verse.verse_key}"
      end
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

    def sanitize_footnote(text = nil, doc: nil)
      @footnotes ||= []

      if text
        processed = text.gsub(/\[\[(.+?)\]\]/) do
          @footnotes << Regexp.last_match(1)
          %(<sup foot_note="#{@footnotes.size}">#{@footnotes.size}</sup>)
        end
        return processed
      elsif doc && @footnotes.any?
        ol = Nokogiri::XML::Node.new('ol', doc)
        ol['class'] = 'footnotes'

        @footnotes.each_with_index do |fn, i|
          li = Nokogiri::XML::Node.new('li', doc)
          li['id']   = "footnote-#{i+1}"
          li.content = "#{i+1}. #{fn}"
          ol.add_child(li)
        end

        doc.add_child(ol)
      end
    end

    def sanitize_text(text)
      #collect footnotes
      processed_text = sanitize_footnote(text)

      formatted = simple_format(processed_text)
      html = formatted.split("\n").map(&:strip).reject(&:empty?).map do |line|
        if line.start_with?('*')
          "<h3>#{line.sub('*', '').strip}</h3>"
        else
          "<p>#{line}</p>"
        end
      end.join

      doc = Nokogiri::HTML.fragment(html)

      # Merge hlt and qpc-hafs in one spans
      doc.css('span.hlt > span.qpc-hafs').each do |qpc_span|
        merged = Nokogiri::XML::Node.new('span', doc)
        merged['class'] = 'qpc-hafs hlt'
        merged.content   = qpc_span.text
        qpc_span.parent.replace(merged)
      end

      doc.css('span.hlt').each do |n|
        if n.text =~ /\A[«{﴿][\s\S]*?[﴾}»]\z/
          n['class'] = 'qpc-hafs hlt'
        end
      end

      doc.css('a[href^="/quran-roots/"]').each do |a|
        if a['href'] =~ %r{^/quran-roots/(.+)}
          r = Nokogiri::XML::Node.new('root', doc)
          r.content = Regexp.last_match(1)
          a.replace(r)
        end
      end

      #append footnote list
      sanitize_footnote(nil, doc: doc)

      "<div class=\"ar\" lang=\"ar\">#{doc.to_html}</div>"
    end


    def prep_data_mathoor(text)
      # Wrap Ayah references
      text = text.gsub(/(\[[ء-ْ ]{1,11}: [\d٠-٩، -]+\])/, '<span class="ayah-ref">\1</span>')

      # Wrap ayah text
      text.gsub(/([«{﴿][\s\S]*?[﴾}»])/, '<span class="qpc-hafs">\1</span>')
    end

    def simple_format(text)
      poetry_wrap = '<p class="poetry">\1</p>'

      text = text.gsub(/\(p-([\d٠-٩]+)\)/, '<p class="page-num">صفحة \1</p>')

      # Replace section separators
      text.gsub!(/\n([⁕* ]+)\n/, '<p class="sep">\1</p>')

      # Wrap Ayah references in a span with a specific class
      text.gsub!(/(\[[ء-ْ ]{1,11}: [\d٠-٩، -]+\])/, '<span class="ayah-tag">\1</span>')

      # Wrap poetry lines marked by '؎' inside paragraph tags
      text.gsub!(/؎ ?(.*?)(?=]])/, poetry_wrap)
      text.gsub!(/؎ ?(.*)\n*/, poetry_wrap)

      # Bold lines that start with '* ' followed by Arabic text
      text.gsub!(/(^|\n)(\* [ء-ي].*)/, '\1<b>\2</b>')

      # Highlight phrases
      text.gsub(/([«{﴿][\s\S]*?[﴾}»])/, '<span class="hlt">\1</span>')
    end
  end
end