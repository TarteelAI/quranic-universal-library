module Exporter
  class ExportAyahTheme < BaseExporter
    attr_accessor :resource_content

    def initialize(resource_content:, base_path:)
      super(base_path: base_path, name: resource_content.sqlite_file_name)
      @resource_content = resource_content
    end

    def export_sqlite(table_name= 'themes')
      db_file_path = "#{@export_file_path}.db"
      statement = create_sqlite_table(db_file_path, table_name, sqlite_db_columns)

      records.each do |record|
        t_verses = record.verse_topics.order('verse_id ASC')

        fields = [
          record.name,
          t_verses.first.verse.chapter_id,
          t_verses.first.verse.verse_number,
          t_verses.last.verse.verse_number,
          record.keywords,
          t_verses.size,
          record.ayah_keys.join(',')
        ]

        statement.execute(fields)
      end

      close_sqlite_table

      db_file_path
    end

    protected

    def sqlite_db_columns
      {
        name: 'TEXT',
        surah_number: 'INTEGER',
        ayah_from: 'INTEGER',
        ayah_to: 'INTEGER',
        keywords: 'TEXT',
        total_ayahs: 'INTEGER',
        ayah_keys: 'TEXT'
      }
    end

    def records
      Topic
        .eager_load(verse_topics: :verse)
    end
  end
end