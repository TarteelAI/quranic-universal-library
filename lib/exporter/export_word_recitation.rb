module Exporter
  class ExportWordRecitation < BaseExporter
    attr_accessor :recitation

    def initialize(base_path:)
      super(base_path: base_path, name: "word_recitation")
    end

    def export_json
      FileUtils.mkdir_p(@export_file_path)
      json_file_path = "#{@export_file_path}.json"

      columns = table_column_names

      json_data = records.map do |row|
        Hash[columns.map { |attr, col| [col, row.send(attr)] }]
      end

      File.open(json_file_path, 'w') do |f|
        f << JSON.generate(json_data, { state: JsonNoEscapeHtmlState.new })
      end

      json_file_path
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"

      table_attributes = table_column_names.keys
      statement = create_sqlite_table(db_file_path, 'words', table_columns)

      records.each do |row|
        fields = table_attributes.map do |attr|
          encode(attr, row.send(attr))
        end
        statement.execute(fields)
      end
      close_sqlite_table

      db_file_path
    end

    protected

    def records
      Word.order('word_index ASC')
    end

    def table_column_names
      {
        chapter_id: 'surah_number',
        verse_id: 'ayah_number',
        position: 'word_number',
        audio_url: 'audio_url',
      }
    end

    def table_columns
      {
        surah_number: 'INTEGER',
        ayah_number: 'INTEGER',
        word_number: 'INTEGER',
        audio_url: 'TEXT'
      }
    end

    def encode(attr, val)
      if attr == :audio_url
        "https://audio.qurancdn.com/#{val}"
      else
        val
      end
    end
  end
end