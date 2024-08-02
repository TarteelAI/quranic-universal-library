module Exporter
  class ExportQuranAyahScript < BaseExporter
    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
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
          json_data[verse.verse_key] = {
            id: verse.id,
            verse_key: verse.verse_key,
            text: verse.send(text_attribute)
          }
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
      statement.execute([verse.verse_index, verse.verse_key, verse.send(text_attribute)])
    end

    def verse_table_columns
      {
        id: 'INTEGER',
        verse_key: 'TEXT',
        text: 'TEXT'
      }
    end
  end
end