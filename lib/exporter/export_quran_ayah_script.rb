module Exporter
  class ExportQuranAyahScript < BaseExporter
    def initialize(resource_content:, base_path:)
      super(
        base_path: base_path,
        resource_content: resource_content
      )

      @resource_content = resource_content
      @page_type = resource_content.meta_value('text_type') == 'code_v1' ? 'page_number' : 'v2_page'
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"

      statement = create_sqlite_table(db_file_path, 'verses', verse_table_columns)
      text_attribute = @resource_content.meta_value('text_type')

      verses.each do |batch|
        batch.each do |ayah|
          export_verse(ayah, statement, text_attribute)
        end
      end

      close_sqlite_table

      db_file_path
    end

    def export_json
      json_file_path = "#{@export_file_path}.json"

      json_data = {}
      text_attribute = @resource_content.meta_value('text_type')

      verses.each do |batch|
        batch.each do |verse|
          data = {
            id: verse.id,
            verse_key: verse.verse_key,
            surah: verse.chapter_id,
            ayah: verse.verse_number,
            text: verse.send(text_attribute)
          }

          if resource_content.glyphs_based?
            data[:page_number] = verse.send(@page_type)
          end

          json_data[verse.verse_key] = data
        end
      end

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    protected

    def verses
      Verse.unscoped.order('verse_index asc').in_batches(of: 1000)
    end

    def export_verse(verse, statement, text_attribute)
      data = [
        verse.verse_index,
        verse.verse_key,
        verse.chapter_id,
        verse.verse_number,
        verse.send(text_attribute)
      ]

      if resource_content.glyphs_based?
        data << verse.send(@page_type)
      end

      statement.execute(data)
    end

    def verse_table_columns
      columns = {
        id: 'INTEGER',
        verse_key: 'TEXT',
        surah: 'INTEGER',
        ayah: 'INTEGER',
        text: 'TEXT'
      }

      if resource_content.glyphs_based?
        columns[:page_number] = 'INTEGER'
      end

      columns
    end
  end
end