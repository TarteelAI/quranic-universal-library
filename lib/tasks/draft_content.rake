namespace :draft_content do
  task import: :environment do
    require 'sqlite3'

    Utils::Downloader.download(
      "http://static-cdn.tarteel.ai/qul/data/surahpedia/projects.json",
      "data/surahpedia/projects.json"
    )
    json_path     = Rails.root.join('data/surahpedia/projects.json')
    projects_data = JSON.parse(File.read(json_path))

    def find_or_create_resource(content_type, project)
      cardinality = { sura: '1_chapter', aya: '1_ayah', word: '1_word' }
      ResourceContent.where(
        name:             project['name'],
        resource_type:    'content',
        cardinality_type: cardinality[content_type.to_sym],
        language_id:      9
      ).first_or_create.tap do |res|
        res.language_name = 'arabic'
        res.description   ||= project['description']
        res.save(validate: false)
      end
    end

    def load_db(project_id)
      db_file = "data/surahpedia/db/project-#{project_id}.sqlite"
      unless File.exist?(db_file)
        Utils::Downloader.download(
          "http://static-cdn.tarteel.ai/qul/data/surahpedia/db/project-#{project_id}.sqlite",
          db_file
        )
      end
      db             = SQLite3::Database.new(db_file)
      db.results_as_hash = true
      db
    end

    def split_paragraphs(text)
      return [] if text.blank?
      text.to_str.split(/\r\n?+/).select(&:present?)
    end

    def simple_format(text)
      paras = split_paragraphs(text)
      return paras.first if paras.size <= 1
      paras.map { |p|
        "<p>#{p.strip.gsub(/\r\n?/, '<br />').gsub(/\n\n?+/, '')}</p>"
      }.join.html_safe
    end

    def import_project_data(project)
      puts "Processing: #{project['id']} - #{project['name']}"
      db    = load_db(project['id'])
      total = db.get_first_value("SELECT COUNT(*) FROM project_contents")
      return if total < 100

      content_type = db.execute("SELECT content_type FROM project_contents LIMIT 1")
                       .first['content_type']
      resource     = find_or_create_resource(content_type, project)
      rows         = db.execute("SELECT * FROM project_contents")

      verse_ids = rows.map { |r| r['aya_id'] }.compact.uniq
      verses    = Verse.where(id: verse_ids).index_by(&:id)
      pos_counters = Hash.new(0) if content_type == 'word'

      rows.each do |row|
        next if row['content'].blank?
        verse = verses[row['aya_id']]

        case content_type
        when 'sura'
          location    = row['sura_id'].to_s
          word_record = nil
        when 'aya'
          location = verse ?
                       "#{verse.chapter_id}:#{verse.verse_number}" :
                       "#{row['sura_id']}:#{row['aya_id']}"
          word_record = nil
        when 'word'
          seq = pos_counters[row['aya_id']] += 1
          chap = verse&.chapter_id || row['sura_id']
          num  = verse&.verse_number  || row['aya_id']
          location = "#{chap}:#{num}:#{seq}"
          word_record = verse ?
                          Word.where(verse_id: verse.id).order(:position).offset(seq - 1).first :
                          nil
        end
        next unless location

        Draft::Content.where(
          resource_content_id: resource.id,
          location:            location
        ).destroy_all

        # BEGIN: **** Tag + Footnote Processing ****
        raw       = row['content'].dup
        footnotes = []
        fn_idx    = 1

        processed = raw.gsub(/¬(.*?)¥/m) do
          footnotes << $1.strip
          "<sup class=\"footnote-ref\">#{fn_idx}</sup>".tap { fn_idx += 1 }
        end

        processed.gsub!(/\{([^}]+)\}/, '<span class="qpc-hafs">\1</span>')

        processed.gsub!(/\[([^\]]+)\]/, '<span class="VerseReference">\1</span>')

        processed.gsub!(/\((ن|ج|ع|ل|ز|ك|هـ|ي)\)/,
                        '<span class="ManuscriptVariant">(\1)</span>')

        processed.gsub!(/(\* قلت:)/, '<span class="AuthorCommentary">\1</span>')

        formatted = simple_format(processed)

        if footnotes.any?
          items = footnotes.each_with_index.map do |txt, i|
            "<li>#{i+1}: #{txt}</li>"
          end.join
          formatted << "<ul class=\"footnote-list\">#{items}</ul>".html_safe
        end

        content = Draft::Content.new(
          resource_content_id: resource.id,
          location:            location
        )

        attrs = {
          draft_text:   formatted,
          imported:     false,
          need_review:  false,
          text_matched: false
        }

        case content_type
        when 'sura'
          attrs.merge!(chapter_id: row['sura_id'], verse_id: nil,         word_id: nil)
        when 'aya'
          attrs.merge!(
            chapter_id: verse&.chapter_id || row['sura_id'],
            verse_id:   verse&.id         || row['aya_id'],
            word_id:    nil
          )
        when 'word'
          attrs.merge!(
            chapter_id: verse&.chapter_id || row['sura_id'],
            verse_id:   verse&.id         || row['aya_id'],
            word_id:    word_record&.id
          )
        end

        content.attributes = attrs
        content.meta_data  = { source_text: row['content_normalized'] }
        content.save(validate: false)

        puts "Imported: #{location}"
      end
    end

    projects_data.each { |project| import_project_data(project) }
  end
end
