module Exporter
  class ExportAyahTheme < BaseExporter
    attr_accessor :resource_content

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_sqlite(table_name = 'themes')
      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, table_name, sqlite_db_columns)

      records.each do |batch|
        batch.each do |record|
          fields = [
            record.theme,
            record.chapter_id,
            record.verse_id_from,
            record.verse_id_to,
            record.keywords.join(','),
            record.verses_count
          ]

          statement.execute(fields)
        end
      end

      close_sqlite_table

      db_file_path
    end

    protected

    def sqlite_db_columns
      {
        theme: 'TEXT',
        surah_number: 'INTEGER',
        ayah_from: 'INTEGER',
        ayah_to: 'INTEGER',
        keywords: 'TEXT',
        total_ayahs: 'INTEGER'
      }
    end

    def records
      AyahTheme
        .in_batches(of: 100)
    end
  end
end