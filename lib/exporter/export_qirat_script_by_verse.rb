module Exporter
  class ExportQiratScriptByVerse < BaseExporter
    def initialize(resource_content:, base_path:)
      super(
        base_path: base_path,
        resource_content: resource_content
      )

      @resource_content = resource_content
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"

      statement = create_sqlite_table(db_file_path, 'verses', verse_table_columns)

      verses.each do |batch|
        batch.each do |verse|
          export_verse(verse, statement)
        end
      end

      close_sqlite_table

      db_file_path
    end

    def export_json
      json_file_path = "#{@export_file_path}.json"

      json_data = {}

      verses.each do |batch|
        batch.each do |verse|
          json_data[verse.key] = {
            id: verse.id,
            verse_key: verse.key,
            surah: verse.chapter_id,
            ayah: verse.verse_number,
            text: verse.text
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
      QuranScript::ByVerse
        .where(resource_content_id: @resource_content.id)
        .order('chapter_id asc, verse_number asc')
        .in_batches(of: 1000)
    end

    def export_verse(verse, statement)
      statement.execute(
        [
          verse.id,
          verse.key,
          verse.chapter_id,
          verse.verse_number,
          verse.text
        ]
      )
    end

    def verse_table_columns
      {
        id: 'INTEGER',
        verse_key: 'TEXT',
        surah: 'INTEGER',
        ayah: 'INTEGER',
        text: 'TEXT'
      }
    end
  end
end
