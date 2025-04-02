# i = Importer::QuranAcademy.new
# i.import(913)


module Importer
  class QuranAcademy < Base
    # quranacademy.org resource ids
    RESOURCE_MAPPING = {
      45 => 3,   # Elmir Kuliyev translation
      79 => 4,   # Abu Adel translation
      913 => 7,  # Russian Tafsir ibne kathir
      914 => 103 # Turkish Tafsir ibne kathir
    }

    def import(id)
      resource = ResourceContent.find(id)

      if RESOURCE_MAPPING[resource.id].blank?
        raise "Mapping is missing for #{resource.name}. Please add the mapping and try again"
      end

      Chapter.find_each do |c|
        import_chapter(c, resource)
      end

      resource.run_draft_import_hooks
    end

    protected

    CSS_CLASSES_MAPPING = {
      'quran-arabic': 'arabic qpc-hafs',
      'arabic-text': 'arabic qpc-hafs',
      'inline-comment': 'blue',
      'hadith-source': 'reference red',
      'hadith-translation': 'translation',
      'hadith-arabic': 'arabic'
    }

    def sanitize_text(text)
      text = clean_up(text.strip)

      TAFSIR_SANITIZER
        .sanitize(text, class_mapping: CSS_CLASSES_MAPPING)
        .html
    end

    def import_chapter(chapter, resource)
      id = RESOURCE_MAPPING[resource.id]
      chapter_data = get_json("https://en.quranacademy.org/quran/js-api/ayat-texts?sura=#{chapter.id}&start_ayat=1&end_ayat=#{chapter.verses_count}&translation_id=#{id}")

      chapter_data.each do |ayah_data|
        verse = Verse.find(ayah_data['ayahId'])
        text = sanitize_text(ayah_data['text'])

        if resource.tafsir?
          import_tafsir(verse, resource, text)
        else
          import_translation(verse, resource, text)
        end
      end
    end

    def import_tafsir(verse, resource, text)
      draft_tafsir = Draft::Tafsir
                       .where(
                         resource_content_id: resource.id,
                         verse_id: verse.id
                       ).first_or_initialize

      existing_tafsir = Tafsir.for_verse(verse, resource)

      draft_tafsir.tafsir_id = existing_tafsir&.id
      draft_tafsir.current_text = existing_tafsir&.text
      draft_tafsir.draft_text = text
      draft_tafsir.text_matched = existing_tafsir&.text == text

      draft_tafsir.verse_key = verse.verse_key

      draft_tafsir.group_verse_key_from = verse.verse_key
      draft_tafsir.group_verse_key_to = verse.verse_key
      draft_tafsir.group_verses_count = 1
      draft_tafsir.start_verse_id = verse.id
      draft_tafsir.end_verse_id = verse.id
      draft_tafsir.group_tafsir_id = verse.id

      draft_tafsir.save(validate: false)
    end

    def import_translation(verse, resource, text)
      current_text = Translation.where(verse_id: verse.id, resource_content_id: resource.id).first&.text.to_s

      draft = Draft::Translation.where(
        verse: verse,
        resource_content_id: resource.id
      ).first_or_initialize

      draft.draft_text = text
      draft.current_text = current_text
      draft.imported = false
      draft.text_matched = text == current_text
      draft.need_review = text != current_text
      draft.save(validate: false)
    end

    def clean_up(text)
      doc = Nokogiri::HTML.fragment(text)
      text_content = ""
      nodes = []

      doc.css('.quran-source').each do |div_element|
        a_element = div_element.at_css('a')

        data_ref = a_element['href'].match(/\d+:\d+(-\d+)?/)[0]

        new_div_element = Nokogiri::XML::Node.new('div', doc)
        new_div_element['class'] = 'reference red'
        new_div_element['data-ref'] = data_ref
        new_div_element.content = a_element.text

        div_element.replace(new_div_element)
      end

      doc = Nokogiri::HTML.fragment(doc.to_s)

      doc.children.each do |node|
        if node.name == 'span' && (node['class'] == 'arabic' || node['class'].to_s.include?('ayat-text--addition'))
          if node['class'] == 'arabic'
            text_content << " " + node.text
          else
            text_content << merge_arabic_nodes(node)
          end
        else
          if text_content.present?
            nodes << "<span class='arabic qpc-hafs'>#{text_content.strip}</span>"
            text_content = ""
          end

          nodes << node.to_s
        end
      end

      if text_content.present?
        nodes << "<span class='arabic qpc-hafs'>#{text_content.strip}</span>"
      end

      nodes.join('')
    end

    def merge_arabic_nodes(node)
      node.text.strip
    end
  end
end