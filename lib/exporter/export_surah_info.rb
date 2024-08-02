module Exporter
  class ExportSurahInfo < BaseExporter
    def initialize(language:, base_path:)
      super(base_path: base_path, name: "surah_info_#{language.iso_code}")
      @language = language
    end

    def export_csv
      csv_file_path = "#{@export_file_path}.csv"
      table_columns = column_names.values
      attributes = column_names.keys

      CSV.open(csv_file_path, 'w') do |csv|
        csv << table_columns
        records.each do |row|
          csv << attributes.map { |attr| row.send(attr) }
        end
      end

      csv_file_path
    end

    def export_json
      json_file_path = "#{@export_file_path}.json"
      json_data = {}

      records.each do |row|
        json_data[row.chapter_id] = Hash[column_names.map { |attr, col| [col, row.send(attr)] }]
      end

      File.open(json_file_path, 'w') do |f|
        f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"

      attributes = column_names.keys
      statement = create_sqlite_table(db_file_path,'surah_infos', sqlite_db_columns)

      records.each do |row|
        fields = attributes.map do |attr|
          row.send(attr)
        end
        statement.execute(fields)
      end
      close_sqlite_table

      db_file_path
    end
    protected

    def records
      ChapterInfo.where(language: @language).order('chapter_id ASC')
    end

    def column_names
      {
        chapter_id: 'surah_number',
        surah_name: 'surah_name',
        text: 'text',
        short_text: 'short_text'
      }
    end

    def sqlite_db_columns
      {
        surah_number: 'INTEGER',
        surah_name: 'TEXT',
        text: 'TEXT',
        short_text: 'TEXT'
      }
    end
  end
end