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
      json_data = {}

      records.each do |batch|
        batch.each do |record|
          json_data[record.location] = Hash[columns.map { |attr, col| [col, record.send(attr)] }]
        end
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

      records.each do |batch|
        batch.each do |record|
          fields = table_attributes.map do |attr|
            encode(attr, record.send(attr))
          end
          statement.execute(fields)
        end
      end
      close_sqlite_table

      db_file_path
    end

    protected

    def records
      Word.unscoped.order('word_index asc').in_batches(of: 1000)
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