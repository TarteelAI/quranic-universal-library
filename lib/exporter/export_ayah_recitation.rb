module Exporter
  class ExportAyahRecitation < BaseExporter
    attr_accessor :recitation

    def initialize(recitation:, base_path:)
      super(base_path: base_path, name: "ayah_recitation_#{recitation.name.to_s}")
      @recitation = recitation
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
      statement = create_sqlite_table(db_file_path, 'verses', table_columns)

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
      AudioFile.where(recitation_id: recitation.id).order('verse_id ASC')
    end

    def table_column_names
      {
        chapter_id: 'surah_number',
        verse_id: 'ayah_number',
        audio_url: 'audio_url',
        duration: 'duration',
        segments: 'segments'
      }
    end

    def table_columns
      {
        surah_number: 'INTEGER',
        ayah_number: 'INTEGER',
        audio_url: 'TEXT',
        duration: 'INTEGER',
        segments: 'TEXT'
      }
    end

    def encode(col, val)
      if col == :segments
        val.to_s.gsub(/\s+/, '')
      else
        val
      end
    end
  end
end