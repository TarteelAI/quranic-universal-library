module Exporter
  class ExportTransliteration < BaseExporter
    attr_accessor :resource_content

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_json
      json_data = {}

      json_file_path = "#{export_file_path}.json"

      records.each do |batch|
        batch.each do |translation|
          json_data[translation.verse_key] = translation.text
        end
      end

      File.open(json_file_path, 'wb') do |file|
        file << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    def export_sqlite
      db_file_path = "#{export_file_path}.db"

      statement = create_sqlite_table(db_file_path, 'transliterations', sqlite_table_columns)

      records.each do |batch|
        batch.each do |record|
          text = record.text

          fields = [
            record.chapter_id,
            record.verse_number,
            record.verse_key,
            text
          ]

          statement.execute(fields)
        end
      end

      close_sqlite_table

      db_file_path
    end

    protected
    def sqlite_table_columns
      {
        sura: 'INTEGER',
        ayah: 'INTEGER',
        ayah_key: 'TEXT',
        text: 'TEXT',
      }
    end

    def sqlite_table_column_names
      {
        chapter_id: 'surah_number',
        verse_id: 'ayah_number',
        verse_key: 'ayah_key',
        text: 'text'
      }
    end

    def records
      Translation
        .where(resource_content_id: resource_content.id)
        .order('verse_id ASC')
        .in_batches(of: 1000)
    end
  end
end