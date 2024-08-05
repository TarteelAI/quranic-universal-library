module Exporter
  class ExportTranslation < BaseExporter
    attr_accessor :resource_content
    TAG_SANITIZER = Rails::Html::WhiteListSanitizer.new
    BRIDGRES_FOOTNOTE_MAPPING = {
      sg: 'Singular',
      pl: 'Plural',
      dl: 'Dual'
    }

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_json(with_footnotes: false)
      json_data = {}

      if with_footnotes
        json_file_path = "#{export_file_path}-with-footnote.json"
      else
        json_file_path = "#{export_file_path}-simple.json"
      end

      records.each do |batch|
        batch.each do |translation|
          if with_footnotes
            json_data[translation.verse_key] = translation_text_with_footnotes(translation, chunks: false)
          else
            json_data[translation.verse_key] = translation_text_without_footnotes(translation)
          end
        end
      end

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    # Export translations with html tags(sup) for footnotes
    def export_json_with_footnotes_tags
      json_data = {}
      json_file_path = "#{export_file_path}-with-footnote-tags.json"

      records.each do |batch|
        batch.each do |translation|
          json_data[translation.verse_key] = translation_text_with_footnotes(translation, chunks: false)
        end
      end

      write_json(json_file_path, json_data)

      json_file_path
    end

    def export_sqlite_with_footnotes_tags
      db_file_path = "#{export_file_path}-with-footnote-tags.db"
      statement = create_sqlite_table(db_file_path, "translation", translation_table_columns(with_footnotes: true))

      records.each do |batch|
        batch.each do |translation|
          text = translation_text_with_footnotes(translation, chunks: false)
          fields = [
            translation.chapter_id,
            translation.verse_number,
            translation.verse_key,
            JSON.generate(text[:t]),
            JSON.generate(text[:f])
          ]

          statement.execute(fields)
        end
      end
      close_sqlite_table

      db_file_path
    end

    def export_json_with_footnotes_chunks
      json_data = {}
      json_file_path = "#{export_file_path}-chunks.json"

      records.each do |batch|
        batch.each do |translation|
          json_data[translation.verse_key] = translation_text_with_footnotes(translation, chunks: true)
        end
      end

      write_json(json_file_path, json_data)

      json_file_path
    end

    def export_sqlite_with_footnotes_chunks
      db_file_path = "#{export_file_path}-chunks.db"
      statement = create_sqlite_table(db_file_path, "translation", translation_table_columns(with_footnotes: true))

      records.each do |batch|
        batch.each do |translation|
          text = translation_text_with_footnotes(translation, chunks: true)
          fields = [
            translation.chapter_id,
            translation.verse_number,
            translation.verse_key,
            JSON.generate(text[:t]),
            JSON.generate(text[:f])
          ]

          statement.execute(fields)
        end
      end
      close_sqlite_table

      db_file_path
    end

    def export_sqlite_with_inline_footnotes
      db_file_path = "#{export_file_path}-inline-footnotes.db"
      statement = create_sqlite_table(db_file_path, "translation", translation_table_columns(with_footnotes: false))

      records.each do |batch|
        batch.each do |translation|
          text = translation_text_with_inline_footnote(translation)

          fields = [
            translation.chapter_id,
            translation.verse_number,
            translation.verse_key,
            JSON.generate(text[:t])
          ]
          statement.execute(fields)
        end
      end
      close_sqlite_table

      db_file_path
    end

    def export_json_with_inline_footnotes
      json_data = {}
      json_file_path = "#{export_file_path}-inline-footnotes.json"

      records.each do |batch|
        batch.each do |translation|
          json_data[translation.verse_key] = translation_text_with_inline_footnote(translation)
        end
      end

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    def export_sqlite(name: 'translation', with_footnotes: false)
      if with_footnotes
        db_file_path = "#{@export_file_path}-with-footnote.db"
      else
        db_file_path = "#{@export_file_path}-simple.db"
      end

      statement = create_sqlite_table(db_file_path, name, translation_table_columns(with_footnotes: with_footnotes))

      records.each do |batch|
        batch.each do |record|
          text = with_footnotes ? translation_text_with_footnotes(record, chunks: false) : translation_text_without_footnotes(record)

          fields = [
            record.chapter_id,
            record.verse_number,
            record.verse_key,
            text[:t]
          ]

          if with_footnotes
            fields << JSON.generate(text[:f])
          end

          statement.execute(fields)
        end
      end

      close_sqlite_table

      db_file_path
    end

    protected

    def translation_text_with_footnotes(translation, chunks: false)
      text = translation.text.to_s

      # brides translation have hard coded footnotes, and needs a custom export
      if text.blank?
        if chunks
          {
            t: [text.to_s.strip],
            f: []
          }
        else
          {
            t: text.to_s.strip,
            f: []
          }
        end
      else
        doc = Nokogiri::HTML::DocumentFragment.parse(text)
        # bridges translation
        if is_bridges_translation? && chunks
          export_bridres_with_footnote(doc, translation)
        else
          if chunks
            export_translation_chunks(doc, translation)
          else
            export_simple_translation(doc, translation)
          end
        end
      end
    end

    def export_translation_chunks(doc, translation)
      footnotes_refs = {}
      footnotes = {}
      foot_note_counter = 1

      doc.children.each do |node|
        if node.name == 'text'
          next
        end

        id = node.attr('foot_note')
        if id.present? && (foot_note = FootNote.where(id: id).first).present?
          # Some footnote also has html tags tags, strip those tags
          foot_note_text = Nokogiri::HTML::DocumentFragment.parse(foot_note.text).text
          stripped = foot_note_text.tr(" ", '').strip

          footnotes[foot_note_counter] = stripped
          footnotes_refs[id] = foot_note_counter
          foot_note_counter += 1
        end
      end

      translation_chunks = []
      doc.children.each do |child|
        id = child.attr('foot_note')

        if id.present?
          translation_chunks << {
            f: footnotes_refs[id]
          }
        else
          translation_chunks << child.text if child.text.presence.present?
        end
      end

      {
        t: translation_chunks,
        f: footnotes
      }
    end

    def export_simple_translation(doc, translation)
      footnotes = {}
      translation.foot_notes.each do |foot_note|
        footnotes[foot_note.id] = foot_note.text
      end

      {
        t: doc.to_s.strip,
        f: footnotes
      }
    end

    def translation_text_without_footnotes(translation)
      text = translation.text
      doc = Nokogiri::HTML::DocumentFragment.parse(text)
      doc.search('a').remove
      doc.search('sup').remove

      {
        t: doc.text.strip
      }
    end

    def translation_text_with_inline_footnote(translation)
      text = translation.text.to_s

      doc = Nokogiri::HTML::DocumentFragment.parse(text)

      doc.search("a sup, sup").each do |node|
        t = node.text.strip.to_sym
        footnote_id = node.attr('foot_note')

        if footnote = BRIDGRES_FOOTNOTE_MAPPING[t]
          node.content = "[[#{footnote}]]"
        elsif footnote_id.present?
          footnote = FootNote.find_by_id(footnote_id)
          if footnote.present?
            node.content = "[[#{footnote.text}]]"
          else
            node.remove
          end
        end
      end

      { t: doc.text }
    end

    def export_bridres_with_footnote(doc, translation)
      # i class s formatting
      # span class h (qirat)
      # sup or a.sup footnote

      hard_coded_footnotes = ['sg', 'pl', 'dl']
      foot_note_tags = ['sup', 'a']

      foot_note_counter = 1
      footnotes = {}
      translation_chunks = []
      last_node_was_footnote = false

      doc.children.each do |node|
        if foot_note_tags.include?(node.name) || hard_coded_footnotes.include?(node.text.strip)
          last_node_was_footnote = true

          if hard_coded_footnotes.include?(node.text.strip)
            translation_chunks << { f: node.text.strip }
          else
            id = node.attr('foot_note')

            if id.present? && (foot_note = FootNote.where(id: id).first).present?
              foot_note_text = Nokogiri::HTML::DocumentFragment.parse(foot_note.text).text
              stripped = foot_note_text.tr(" ", '').strip

              translation_chunks << { f: foot_note_counter }
              foot_note_counter += 1
            end
          end
        elsif node.name == 'i'
          translation_chunks << { i: node.text.strip }
        elsif node.name == 'span'
          translation_chunks << { b: node.text.strip }
        end
      end

      {
        t: translation_chunks,
        f: footnotes
      }
    end

    def translation_table_columns(with_footnotes: false)
      cols = {
        sura: 'INTEGER',
        ayah: 'INTEGER',
        ayah_key: 'TEXT',
        text: 'TEXT',
      }

      if with_footnotes
        cols[:footnotes] = 'TEXT'
      end

      cols
    end

    def table_column_names
      {
        chapter_id: 'surah_number',
        verse_id: 'ayah_number',
        verse_key: 'ayah_key',
        footnotes: 'footnotes',
        text: 'text'
      }
    end

    def records
      Translation
        .where(resource_content_id: resource_content.id)
        .order('verse_id ASC')
        .in_batches(of: 1000)
    end

    def is_bridges_translation?
      149 == resource_content.id
    end
  end
end