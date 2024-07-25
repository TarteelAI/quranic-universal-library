module Exporter
  class ExportTranslation < BaseExporter
    attr_accessor :resource_content

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_json
      @json_data = {}
      json_file_path = "#{export_file_path}.json"

      records.find_each do |translation|
        @json_data[translation.verse_key] = translation_text_with_footnotes(translation)
      end

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(@json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    # Export translations with tags for footnotes
    def export_json_with_footnotes_tags
      @json_data = {}
      json_file_path = "#{export_file_path}-with-footnote-tags.json"

      records.find_each do |translation|
        footnotes = {}
        translation.foot_notes.each do |foot_note|
          footnotes[foot_note.id] = foot_note.text
        end

        @json_data[translation.verse_key] = {
          t: translation.text.to_s,
          f: footnotes
        }
      end

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(@json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    def export_sqlite
      if @json_data.blank?
        export_json
      end

      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, 'tafsir', sqlite_db_columns)

      @json_data.each do |verse_key, data|
        fields = [verse_key]

        if data.is_a?(String)
          group_ayah_key = data
          fields += [group_ayah_key, '', '', '', '']
        else
          group_keys = data[:ayah_keys] || [verse_key]
          fields += [verse_key, group_keys.first, group_keys.last, group_keys.join(','), data[:text]]
        end

        statement.execute(fields)
      end
      close_sqlite_table

      db_file_path
    end

    protected

    def translation_text_with_footnotes(translation)
      text = translation&.text
      footnotes_refs = {}
      footnotes = {}

      if text.blank? || (!text.include?('<sup') && !translation.resource_content_id == 149)
        result = {
          t: [text.to_s.strip]
        }
      else
        doc = Nokogiri::HTML::DocumentFragment.parse(text)
        if translation.resource_content_id == 149
          result = export_bridres_with_footnote(doc)
        else
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

          result = {
            t: translation_chunks,
            f: footnotes
          }
        end
      end

      result
    end

    def export_bridres_with_footnote(doc)
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


    def sqlite_db_columns
      {
        ayah_key: 'TEXT',
        group_ayah_key: 'TEXT',
        from_ayah: 'TEXT',
        to_ayah: 'TEXT',
        ayah_keys: 'TEXT',
        text: 'TEXT',
      }
    end

    def records
      Translation.where(resource_content_id: resource_content.id).order('verse_id ASC')
    end
  end
end