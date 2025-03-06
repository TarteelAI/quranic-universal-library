=begin
i=Importer::IslamEnc.new
i.import_draft 'ur'
i.import_draft 'ar'

i.import_draft 'tr'
i.import_draft 'ru'

i.import_draft 'id'
i.import_draft 'fa'

=end

module Importer
  class IslamEnc < Base
    DEBUG = true

    MAPPING = {
      ur: 906,
      tr: 907,
      fa: 909, # persian_saadi
      id: 910,
      ru: 911,
      ar: 912
    }

    def import_albainin_saadi
      require 'csv'
      resource = ResourceContent.find(915)
      url = "https://gist.githubusercontent.com/naveed-ahmad/e1d0a6d1f7e2b99d3468319fe30e1f90/raw/64cc9ca2d6b225f12c5ce69f49b6f524363ee97f/quran-translation-sq-saadi-2023-11-12%252013%252035%252057.csv"
      content = URI.parse(url).read
      csv_data = CSV.parse(content)

      csv_data.each do |row|
        verse = Verse.find_by(verse_key: "#{row[0]}:#{row[1]}")
        text = sanitize_text(row[2], {})
        record = create_draft_tafsir(text, verse, resource, [verse])

        puts record.id
      end

      resource.run_draft_import_hooks

      updated = {}
      Draft::Tafsir.where(resource_content_id: resource.id).order('verse_id ASC').each do |t|
        next if updated[t.verse_id]

        if t.draft_text.strip.downcase == '<i>Shko ne ajetin tjeter per vazhdimin e tefsirit</i>'.downcase
          updated[t.verse_id] = true

          first_ayah = Verse.find_by(verse_key: t.group_verse_key_from)
          last_ayah = Verse.find_by(verse_key: t.group_verse_key_to)

          next_group_ayah_key = last_ayah.next_ayah.verse_key
          last_ayah = Verse.find_by(verse_key: next_group_ayah_key)

          first_ayah.id.upto(last_ayah.id) do |n|
            updated[n] = true
          end

          Draft::Tafsir
            .where(resource_content_id: resource.id)
            .where(verse_id: (first_ayah.id..last_ayah.id))
            .update_all(
              group_verse_key_from: first_ayah.verse_key,
              group_verse_key_to: last_ayah.verse_key,
              group_verses_count: (last_ayah.id - first_ayah.id) + 1,
              start_verse_id: first_ayah.id,
              end_verse_id: last_ayah.id,
              group_tafsir_id: first_ayah.id
            )

          text = Draft::Tafsir
                   .where(resource_content_id: resource.id, verse_id: last_ayah.id).first.draft_text

          Draft::Tafsir
            .where(resource_content_id: resource.id, verse_id: first_ayah.id).update(draft_text: text)
        end
      end
    end

    def import(lang, chapter_number = nil)
      language = Language.find_by(iso_code: lang)

      resource = if MAPPING[lang.to_sym]
                   ResourceContent.find(MAPPING[lang.to_sym])
                 else
                   ResourceContent.tafsirs.where(
                     language_id: language.id,
                     name: 'Tafsir As-Saadi'
                   ).first_or_initialize
                 end

      resource.cardinality_type = ResourceContent::CardinalityType::NVerse
      resource.resource_type = 'content'
      resource.language_name = language.name.downcase
      resource.save(validate: false)

      new_tafsir_ids = []

      if chapter_number
        chapter = Chapter.find(chapter_number)
        groups = send("process_#{lang}_tafsir", "data/islam_enc/#{lang}/#{chapter_number}.html")
        new_tafsir_ids += import_groups(resource, groups, chapter, lang)
      else
        files = Dir["data/islam_enc/#{lang}/*.html"].sort_by do |file|
          file[/\d+/].to_i
        end

        files.each do |file|
          chapter = Chapter.find file[/\d+/].to_i
          groups = send("process_#{lang}_tafsir", file)
          new_tafsir_ids += import_groups(resource, groups, chapter, lang)
        end
      end

      resource.run_draft_import_hooks
    end

    def download_all
      ['ar', 'ru', 'ur', 'id', 'fa', 'tr'].each do |language|
        download(language)
      end
    end

    def download(language)
      FileUtils.mkdir_p("data/islam_enc/#{language}")

      1.upto(114) do |chapter_id|
        url = "https://saadi.islamenc.com/#{language}/browse/sura/#{chapter_id}"

        puts "downloading #{language} #{chapter_id}"
        result = get_html(url)
        File.open("data/islam_enc/#{language}/#{chapter_id}.html", "wb") do |file|
          file.puts result.body
        end
      end
    end

    def detect_classes
      mapping = {
        ur: {},
        ru: {},
        ar: {},
        fa: {},
        id: {},
        tr: {}
      }

      mapping.keys.each do |key|
        Dir["data/islam_enc/#{key}/*.html"].each do |f|
          begin
            docs = Nokogiri::HTML::DocumentFragment.parse(File.read(f))

            klasses = docs.search(".container .col span").map do |e|
              e.attribute('class')&.value
            end

            klasses.each do |c|
              mapping[key][c] ||= 0
              mapping[key][c] += 1
            end
          end
        end
      end

      output = {
        "ur" => {
          "c4 hafs" => 22928,
          "c2" => 22154,
          "c3" => 116,
          "c6" => 14334,
          "c5" => 5435, # group count
          "c4" => 16674
        },
        "ru" => {
          "c3" => 3732,
          "c2" => 20051,
          "c4 hafs" => 22954,
          "c6" => 15253,
          "c5" => 647,
          "c1" => 254
        },
        "ar" => {
          "c4 hafs" => 23034,
          "c2" => 6276,
          "c3" => 153,
          "c6" => 11995,
          "c5" => 692
        },
        "fa" => {
          "c4 hafs" => 22948,
          "c2" => 11497,
          "c3" => 2333,
          "c6" => 18046,
          "c4" => 15247,
          "c5" => 2444
        },
        "id" => {
          "c2" => 28720,
          "c4 hafs" => 22936,
          "c6" => 14308,
          "c3" => 117,
          "c4" => 11729,
          "c5" => 1123
        },
        "tr" => {
          "c2" => 13297,
          "c4 hafs" => 22819,
          "c3" => 117,
          "c6" => 18025,
          "c1" => 18660,
          "c5" => 737,
          "c4" => 3
        }
      }
    end

    def export_draft(lang)
      resource = ResourceContent.find(MAPPING[lang.to_sym])

      json = {}

      Draft::Tafsir.where(resource_content_id: resource.id).each do |t|
        json[t.verse_key] = {
          draft_text: t.draft_text,
          group_verse_key_from: t.group_verse_key_from,
          group_verse_key_to: t.group_verse_key_to,
          group_verses_count: t.group_verses_count,
          group_tafsir_id: t.group_tafsir_id,
          start_verse_id: t.start_verse_id,
          end_verse_id: t.end_verse_id,
          tafsir_id: t.tafsir_id,
          meta_data: t.meta_data
        }
      end

      File.open("data/islam_enc/saadi-exported/saadi-#{lang}.json", 'wb') do |file|
        file << JSON.generate(json, { state: JsonNoEscapeHtmlState.new })
      end
    end

    def import_draft(lang)
      resource = ResourceContent.find(MAPPING[lang.to_sym])
      data = get_json("https://quran-assets.tarteel.ai/qul-data/saadi-exported/saadi-#{lang}.json")
      #data = JSON.parse(File.read("saadi-#{lang}.json"))

      data.keys.each do |key|
        verse = Verse.find_by(verse_key: key)
        draft = Draft::Tafsir.where(
          resource_content_id: resource.id,
          verse_id: verse.id
        ).first_or_initialize

        draft.attributes = data[key]

        existing_tafsir = Tafsir
                            .where(resource_content_id: resource.id)
                            .where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse.id)
                            .first

        draft.tafsir_id = existing_tafsir&.id
        draft.current_text = existing_tafsir&.text
        draft.text_matched = existing_tafsir&.text == draft.draft_text
        draft.verse_key = verse.verse_key
        draft.need_review = !draft.text_matched || (existing_tafsir && (existing_tafsir.start_verse_id != draft.start_verse_id || existing_tafsir.end_verse_id != draft.end_verse_id))
        draft.imported = false
        draft.save
        puts draft.id
      end

      puts "DONE, running after import hooks"
      resource.run_draft_import_hooks
    end

    protected

    def process_ru_tafsir(file)
      css_class_mapping = {
        c2: 'green',
        c3: 'brown',
        c4: 'brown',
        c6: 'blue',
        c5: 'brown',
        c1: 'brown'
      }

      docs = Nokogiri::HTML::DocumentFragment.parse(File.read(file))
      container = docs.search(".container .col").first
      group_reg = /^\(\d+[-\s]*(\d+)\)/

      tafsir_groups = {}
      container.search(".alert.alert-warning").each do |group_dom|
        ayah_group_parent = group_dom.parent
        group = parse_ayah_group(group_dom)

        group_dom.remove
        ayah_group_parent.search('.hafs').each do |a|
          a.parent.remove
        end
        group_translation = ayah_group_parent.children.to_s.strip
        ayah_group_parent.remove

        if group_translation.present?
          group_translation = fix_ayah_text sanitize_text("<p class=translation>#{group_translation}</p>", css_class_mapping)
        end

        tafsir_groups[group] = {
          texts: [group_translation]
        }
      end

      container.search("._ar,.btn-light").remove # remove Arabic saddi
      container.search(".aya-anchor").remove

      if info = container.search(".alert.alert-info")[0]
        info.parent.remove
      end

      last_ayah_group = nil

      container.search("div").each do |div|
        ayah_range = div.search(".c2").first&.text.to_s

        unless ayah_range.match(/^\(\d+[-\s]?(\d+)?\)/)
          ayah_range = nil
        end

        text = div.to_s.strip
        next if ['Makkiyah', 'Madaniyah'].include?('text')

        parsed_text = sanitize_text(text, css_class_mapping)
        parsed_text = fix_ayah_text(parsed_text)

        if ayah_range.present?
          group = ayah_range.scan(/\d+/).map(&:to_i)
        else
          group = last_ayah_group || [1]
        end

        group = last_ayah_group if group.blank?
        ayah_group = find_group(tafsir_groups, group.first)

        if ayah_range.blank?
          # some ayah ranges has the info, like reason for revelation etc.
          # make it part of the text
          tafsir_groups[ayah_group][:texts].push parsed_text
        else
          tafsir_groups[ayah_group][:texts].push parsed_text
        end

        last_ayah_group = ayah_group
      end

      # File.open("debugg.html", "wb") do |f|
      #   f.puts docs.to_s
      # end

      tafsir_groups
    rescue Exception => e
      Sentry.capture_exception(e)
    end

    def process_id_tafsir(file)
      css_class_mapping = {
        c2: 'green',
        c3: 'brown',
        c4: 'brown',
        c6: 'blue',
        c5: 'brown'
      }

      docs = Nokogiri::HTML::DocumentFragment.parse(File.read(file))
      container = docs.search(".container .col").first
      group_reg = /^\(\d+[-\s]*(\d+)\)/

      tafsir_groups = {}
      container.search(".alert.alert-warning").each do |group_dom|
        ayah_group_parent = group_dom.parent
        group = parse_ayah_group(group_dom)

        group_dom.remove
        ayah_group_parent.search('.hafs').each do |a|
          a.parent.remove
        end
        group_translation = ayah_group_parent.children.to_s.strip
        ayah_group_parent.remove

        if group_translation.present?
          group_translation = fix_ayah_text sanitize_text("<p class=translation>#{group_translation}</p>", css_class_mapping)
        end

        tafsir_groups[group] = {
          texts: [group_translation]
        }
      end

      container.search("._ar,.btn-light").remove # remove Arabic saddi
      container.search(".aya-anchor").remove

      if info = container.search(".alert.alert-info")[0]
        info.parent.remove
      end

      last_ayah_group = nil

      container.search("div").each do |div|
        ayah_range = div.search(".c2").first&.text.to_s

        unless ayah_range.match(/^\(\d+[-\s]?(\d+)?\)/)
          ayah_range = nil
        end

        text = div.to_s.strip
        next if ['Makkiyah', 'Madaniyah'].include?('text')

        parsed_text = sanitize_text(text, css_class_mapping)
        parsed_text = fix_ayah_text(parsed_text)

        if ayah_range.present?
          group = ayah_range.scan(/\d+/).map(&:to_i)
        else
          group = last_ayah_group || [1]
        end

        group = last_ayah_group if group.blank?
        ayah_group = find_group(tafsir_groups, group.first)

        if ayah_range.blank?
          # some ayah ranges has the info, like reason for revelation etc.
          # make it part of the text
          tafsir_groups[ayah_group][:texts].push parsed_text
        else
          tafsir_groups[ayah_group][:texts].push parsed_text
        end

        last_ayah_group = ayah_group
      end

      # File.open("debugg.html", "wb") do |f|
      #   f.puts docs.to_s
      # end

      tafsir_groups
    rescue Exception => e
      Sentry.capture_exception(e)
    end

    def process_ar_tafsir(file)
      css_class_mapping = {
        c3: 'brown',
        c6: 'blue',
        c5: 'brown',
        c4: 'arabic qpc-hafs brown',
      }

      docs = Nokogiri::HTML::DocumentFragment.parse(File.read(file))
      container = docs.search(".container .col").first

      tafsir_groups = {}
      container.search(".alert.alert-warning").each do |group_dom|
        group_dom.search(".aya-anchor").remove
        group = group_dom.text.strip.scan(/\d+/).map(&:to_i)
        tafsir_groups[group] = { texts: [] }
      end

      container.search(".alert.alert-warning").each do |group_dom|
        group_dom.parent.remove # remove Arabic and Urdu translation
      end

      container.search(".btn-light").remove # remove Arabic saddi
      container.search(".aya-anchor").remove

      if info = container.search(".alert.alert-info")[0]
        info.parent.remove
      end

      last_ayah_group = nil

      container.search("div").each do |div|
        ayah_range = div.search(".c4.hafs:first-child").text.to_s.strip

        text = div.to_s
        parsed_text = sanitize_text(text, css_class_mapping)
        parsed_text = fix_ayah_text(parsed_text)

        if ayah_range.blank?
          group = last_ayah_group || [1]
        else
          group = ayah_range.scan(/\d+/).map(&:to_i)
        end

        group = last_ayah_group if group.blank?
        ayah_group = find_group(tafsir_groups, group.first)

        if ayah_range.blank?
          # some ayah ranges has the info, like reason for revelation etc.
          # make it part of the text
          tafsir_groups[ayah_group][:texts].push parsed_text
        else
          tafsir_groups[ayah_group][:texts].push parsed_text
        end

        last_ayah_group = ayah_group
      end

      File.open("debug.html", "wb") do |f|
        f.puts docs.to_s
      end

      tafsir_groups
    rescue Exception => e
      puts e.message
    end

    def process_fa_tafsir(file)
      css_class_mapping = {
        c2: 'green',
        c3: 'brown',
        c4: 'arabic qpc-hafs brown',
        c6: 'blue',
        c5: 'brown'
      }

      docs = Nokogiri::HTML::DocumentFragment.parse(File.read(file))
      container = docs.search(".container .col").first

      tafsir_groups = {}
      container.search(".alert.alert-warning").each do |group_dom|
        ayah_group_parent = group_dom.parent
        group = parse_ayah_group(group_dom)

        group_dom.remove
        ayah_group_parent.search('.hafs').each do |a|
          a.parent.remove
        end
        group_translation = ayah_group_parent.children.to_s.strip
        ayah_group_parent.remove

        if group_translation.present?
          group_translation = fix_ayah_text sanitize_text("<p class=translation>#{group_translation}</p>", css_class_mapping)
        end

        tafsir_groups[group] = {
          texts: [group_translation]
        }
      end

      container.search("._ar,.btn-light").remove # remove Arabic saddi
      container.search(".aya-anchor").remove

      if info = container.search(".alert.alert-info")[0]
        info.parent.remove
      end

      last_ayah_group = nil

      container.search("div").each do |div|
        ayah_range = div.search(".c2").text.strip
        text = div.to_s
        parsed_text = sanitize_text(text, css_class_mapping)
        parsed_text = fix_ayah_text(parsed_text)

        if ayah_range.present?
          group = ayah_range.scan(/\d+/).map(&:to_i)
        else
          group = last_ayah_group || [1]
        end

        group = last_ayah_group if group.blank?
        ayah_group = find_group(tafsir_groups, group.first)

        if ayah_range.blank?
          # some ayah ranges has the info, like reason for revelation etc.
          # make it part of the text
          tafsir_groups[ayah_group][:texts].push parsed_text
        else
          tafsir_groups[ayah_group][:texts].push parsed_text
        end

        last_ayah_group = ayah_group
      end

      # File.open("debugg.html", "wb") do |f|
      #   f.puts docs.to_s
      # end

      tafsir_groups
    rescue Exception => e
    end

    def process_tr_tafsir(file)
      css_class_mapping = {
        c2: 'green',
        c3: 'brown',
        c6: 'blue',
        c1: 'brown',
        c5: 'brown',
        c4: 'brown'
      }

      docs = Nokogiri::HTML::DocumentFragment.parse(File.read(file))
      container = docs.search(".container .col").first

      tafsir_groups = {}

      container.search(".alert.alert-warning").each do |group_dom|
        ayah_group_parent = group_dom.parent
        group = parse_ayah_group(group_dom)

        group_dom.remove
        ayah_group_parent.search('.hafs').each do |a|
          a.parent.remove
        end

        group_translation = ayah_group_parent.children.to_s.strip
        ayah_group_parent.remove

        if group_translation.present?
          group_translation = fix_ayah_text sanitize_text("<p class=translation>#{group_translation}</p>", css_class_mapping)
        end

        tafsir_groups[group] = {
          texts: [group_translation]
        }
      end

      container.search("._ar,.btn-light").remove # remove Arabic saddi
      container.search(".aya-anchor").remove

      if info = container.search(".alert.alert-info")[0]
        info.parent.remove
      end

      last_ayah_group = nil

      container.search("div").each do |div|
        ayah_range = nil

        div.children.each do |c|
          begin
            if c.text? && c.text.strip.blank?
              c.remove
            else
              if ayah_range.blank?
                match = c.text.to_s.strip.match(/^\d+[-]?\d*./)

                if match
                  ayah_range = match.to_s.scan(/\d+/).map(&:to_i)
                end
              end
            end
          end
        end

        text = div.to_s
        parsed_text = sanitize_text(text, css_class_mapping)
        parsed_text = fix_ayah_text(parsed_text)

        if ayah_range.blank?
          group = last_ayah_group || [1]
        else
          group = ayah_range
        end

        ayah_group = find_group(tafsir_groups, group.first)

        if ayah_range.blank?
          # some ayah ranges has the info, like reason for revelation etc.
          # make it part of the text
          tafsir_groups[ayah_group][:texts].push parsed_text
        else
          tafsir_groups[ayah_group][:texts].push parsed_text
        end

        last_ayah_group = ayah_group
      end

      File.open("debugg.html", "wb") do |f|
        f.puts docs.to_s
      end

      tafsir_groups
    rescue Exception => e
      puts e.message
      puts e.backtrace
    end

    def process_ur_tafsir(file)
      css_class_mapping = {
        #"c4 hafs" => 22928,
        c4: 'arabic qpc-hafs brown',
        c2: 'green',
        c3: 'brown',
        c6: 'blue',
        c5: 'brown' # group count
      }

      docs = Nokogiri::HTML::DocumentFragment.parse(File.read(file))
      container = docs.search(".container .col").first

      tafsir_groups = {}

      container.search(".alert.alert-warning").each do |group_dom|
        ayah_group_parent = group_dom.parent
        group = parse_ayah_group(group_dom)
        group_dom.remove

        ayah_group_parent.search('.hafs').each do |a|
          a.parent.remove
        end

        group_translation = ayah_group_parent.children.to_s.strip
        ayah_group_parent.remove

        if group_translation.present?
          group_translation.gsub! 'e', 'ﷺ'
          group_translation.gsub! 'o', "علیہ السلام"
          group_translation = fix_ayah_text sanitize_text("<p class=translation>#{group_translation}</p>", css_class_mapping)
        end

        tafsir_groups[group] = {
          texts: [group_translation]
        }
      end

      container.search("._ar,.btn-light").remove # remove Arabic saddi
      container.search(".aya-anchor").remove

      if info = container.search(".alert.alert-info")[0]
        info.parent.remove
      end

      last_ayah_group = nil

      container.search("div").each do |div|
        ayah_range = div.search(".c5").text.strip
        text = div.to_s
        text.gsub! 'e', 'ﷺ'
        text.gsub! 'o', " علیہ السلام "
        parsed_text = sanitize_text(text, css_class_mapping)
        parsed_text = fix_ayah_text(parsed_text)

        if ayah_range.present?
          group = ayah_range.scan(/\d+/).map(&:to_i)
        else
          group = last_ayah_group || [1]
        end

        ayah_group = find_group(tafsir_groups, group.first)

        if ayah_range.blank?
          # some ayah ranges has the info, like reason for revelation etc.
          # make it part of the text
          tafsir_groups[ayah_group][:texts].push parsed_text
        else
          tafsir_groups[ayah_group][:texts].push parsed_text
        end

        last_ayah_group = ayah_group
      end

      File.open("debugg.html", "wb") do |f|
         f.puts docs.to_s
       end

      tafsir_groups
    end

    def import_groups(resource, groups, chapter, lang)
      ids = []

      groups.keys.each do |group|
        verses = chapter.verses.where(verse_number: group).order('verse_number asc')

        text = groups[group][:texts].join('')
        tafsir = create_draft_tafsir(text, verses.first, resource, verses)

        puts "#{resource.name} #{verses.first.verse_key} - #{tafsir.id}"
        ids.push(tafsir.id)
      end

      ids
    end

    def find_group(tafsir_groups, ayah)
      ayah = ayah.to_i

      ayah_group = tafsir_groups.keys.detect do |group|
        if group.length == 1
          group.include?(ayah.to_i)
        else
          first, last = group
          ayah >= first && ayah <= last
        end
      end

      ayah_group
    end

    def sanitize_text(text, class_mapping)
      TAFSIR_SANITIZER.sanitize(text, class_mapping: class_mapping, split_text: false).html
    end

    def fix_ayah_text(text)
      char_mapping = {
        "ہ": "ه",
        "ی": "ي",
        "ک": "ك",
        "ھ": "ه",
        "ْ": "ۡ",
        "٘": "",
      }

      docs = Nokogiri::HTML::DocumentFragment.parse(text)
      docs.search(".qpc-hafs").each do |dom|
        content = dom.content
        char_mapping.each do |k, v|
          content = content.gsub k.to_s, v.to_s
        end

        dom.content = content
      end

      docs.to_s
    end

    def parse_ayah_group(group_dom)
      group = group_dom.text.strip.scan(/\d+/).map(&:to_i)
      group = group - [0] # Some ayah group has weird 0 value []0-29] for Urdu for example
      group
    end
  end
end