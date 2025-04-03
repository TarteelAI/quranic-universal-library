module Exporter
  class ExportAyahRecitation < BaseExporter
    attr_accessor :recitation

    def initialize(recitation:, base_path:, resource_content:)
      super(
        base_path: base_path,
        name: "ayah_recitation_#{resource_content.sqlite_file_name}",
        resource_content: resource_content
      )

      @recitation = recitation
    end

    def export_json
      FileUtils.mkdir_p(@export_file_path)
      json_file_path = "#{@export_file_path}.json"

      json_data = {}

      records.each do |batch|
        batch.each do |row|
          key = row.verse_key || "#{row.chapter_id}:#{row.verse_number}"
          json_data[key] = {
            surah_number: row.chapter_id,
            ayah_number: row.verse_number,
            audio_url: row.audio_url,
            duration: row.duration,
            segments: row.get_segments
          }
        end
      end

      write_json(json_file_path, json_data)

      json_file_path
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"

      table_attributes = table_column_names.keys
      statement = create_sqlite_table(db_file_path, 'verses', table_columns)

      records.each do |batch|
        batch.each do |row|
          fields = table_attributes.map do |attr|
            encode(attr, row.send(attr))
          end
          statement.execute(fields)
        end
      end

      close_sqlite_table

      db_file_path
    end

    protected

    def records
      AudioFile.where(recitation_id: recitation.id).order('verse_id ASC').in_batches(of: 1000)
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