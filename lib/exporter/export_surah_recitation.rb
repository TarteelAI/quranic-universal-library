module Exporter
  class ExportSurahRecitation < BaseExporter
    attr_accessor :recitation

    def initialize(recitation:, base_path:)
      super(base_path: base_path, name: "surah_recitation_#{recitation.name.to_s.downcase.gsub(/\s+/, '-')}")
      @recitation = recitation
    end

    def export_json
      FileUtils.mkdir_p(@export_file_path)
      surah_json_file_path = "#{@export_file_path}/surah.json"
      segments_json_file_path = "#{@export_file_path}/segments.json"
      surah_data = {}

      audio_files.map do |row|
        surah_data[row.chapter_id] = Hash[surah_table_column_names.map { |attr, col| [col, row.send(attr)] }]
      end

      segments_data = {}
      segments.each do |batch|
        batch.each do |segment|
          segments_data[segment.verse_key] = {
            segments: segment.segments,
            duration_sec: segment.duration.to_i.abs,
            duration_ms: segment.duration_ms.to_i.abs,
            timestamp_from: segment.timestamp_from,
            timestamp_to: segment.timestamp_to
          }
        end
      end

      write_json(surah_json_file_path, surah_data)
      write_json(segments_json_file_path, segments_data)

      @export_file_path
    end

    def export_sqlite
      db_file_path = "#{@export_file_path}.db"

      surah_table_attributes = surah_table_column_names.keys
      segment_table_attributes = segments_table_columns.keys

      surah_statement = create_sqlite_table(db_file_path, 'surah_list', surah_table_columns)
      segments_statement = create_sqlite_table(db_file_path, 'segments', segments_table_columns)

      audio_files.each do |row|
        fields = surah_table_attributes.map do |attr|
          row.send(attr)
        end
        surah_statement.execute(fields)
      end

      segments.each do |batch|
        batch.each do |row|
          fields = segment_table_attributes.map do |attr|
            encode(attr, row.send(attr))
          end

          segments_statement.execute(fields)
        end
      end

      close_sqlite_table

      db_file_path
    end

    protected

    def audio_files
      recitation.chapter_audio_files.order('chapter_id ASC')
    end

    def segments
      Audio::Segment
        .where(audio_recitation_id: recitation.id)
        .order('verse_id ASC')
        .in_batches(of: 1000)
    end

    def surah_table_column_names
      {
        chapter_id: 'surah_number',
        audio_url: 'audio_url',
        duration: 'duration'
      }
    end

    def surah_table_columns
      {
        surah_number: 'INTEGER',
        audio_url: 'TEXT',
        duration: 'INTEGER'
      }
    end

    def segments_table_columns
      {
        surah_number: 'INTEGER',
        ayah_number: 'INTEGER',
        duration_sec: 'INTEGER',
        timestamp_from: 'INTEGER',
        timestamp_to: 'INTEGER',
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