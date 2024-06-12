# Helper class for importing Greentech segments data
require 'sqlite3'

module GreenTechSegments
  class SegmentDbFile < ApplicationRecord
    attr_reader :recitation

    def self.import(file_path, recitation_id, remove_existing)
      if File.extname(file_path) == '.csv'
        csv_to_db = GreenTechSegments::CsvToSqlite3.new(file_path)
        output_file_name = file_path.gsub('.csv', '.db')
        FileUtils.rm(output_file_name) if File.exist?(output_file_name)
        file_path = csv_to_db.convert(output_file_name)
      end

      SegmentDbFile.establish_connection({
                                           adapter: 'sqlite3',
                                           database: file_path
                                         })

      SegmentDbFile.table_name = 'timings'
      file = SegmentDbFile.new
      file.import(recitation_id, remove_existing: remove_existing)
    end

    def self.export(recitation, format, chapter_id=nil)
      segments = Audio::Segment.where(audio_recitation_id: recitation.id).order('verse_id asc')

      if chapter_id.present?
        segments = segments.where(chapter_id: chapter_id)
      end

      if format == 'db'
        file_path = "#{Rails.root}/tmp/segments_#{recitation.id}.db"
        FileUtils.rm(file_path) if File.exist?(file_path)

        export_sqlite_db(segments, file_path)
      else
        file_path = "#{Rails.root}/tmp/segments_#{recitation.id}.csv"
        export_json(segments, file_path)
      end

      file_path
    end

    def import(recitation_id, remove_existing: false)
      fix_db_column_names
      SegmentDbFile.reset_column_information

      @recitation = Audio::Recitation.find(recitation_id)
      #Audio::Segment.where(audio_recitation_id: recitation.id).delete_all if remove_existing

      Verse.unscoped.order('verse_index ASC').find_each do |verse|
        verse_data = SegmentDbFile.where(
          sura: verse.chapter_id,
          ayah: verse.verse_number
        ).first
        next if verse_data.blank?

        next_verse_data = SegmentDbFile.where(
          sura: verse.chapter_id,
          ayah: verse.verse_number + 1
        ).first

        import_timing_for_verse verse, verse_data, next_verse_data, @recitation
      end

      update_audio_stats
      prepare_segment_percentile
    end

    protected
    def self.export_sqlite_db(segments, file_path)
      SegmentDbFile.establish_connection({
                                           adapter: 'sqlite3',
                                           database: file_path
                                         })

      SegmentDbFile.table_name = 'timings'

      db = SQLite3::Database.new(file_path)
      table_name = 'timings'

      columns = ['sura', 'ayah', 'start_time', 'end_time', 'words']
      create_table_sql = "CREATE TABLE IF NOT EXISTS #{table_name} (#{columns.map { |c| "#{c} TEXT" }.join(', ')});"
      db.execute(create_table_sql)

      insert_sql = "INSERT INTO #{table_name} (#{columns.join(', ')}) VALUES (#{columns.map { '?' }.join(', ')});"
      insert_statement = db.prepare(insert_sql)

      segments.each do |segment|
        data = [
          segment.chapter_id,
          segment.verse_number,
          segment.timestamp_from,
          segment.timestamp_to,
          segment.segments.join(',')
        ]
        insert_statement.execute(data)
      end

      insert_statement.close
      db.close
    end

    def self.export_json(segments, file_path)
      columns = ['sura', 'ayah', 'start_time', 'end_time', 'words']

      CSV.open(file_path, "wb") do |csv|
        csv << columns

        segments.each do |segment|
          data = [
            segment.chapter_id,
            segment.verse_number,
            segment.timestamp_from,
            segment.timestamp_to,
            segment.segments.join(',')
          ]

          csv << data
        end
      end
    end

    def prepare_segment_percentile
      Chapter.find_each do |chapter|
        audio_file = Audio::ChapterAudioFile.where(audio_recitation_id: recitation.id, chapter_id: chapter.id).first
        total_duration = audio_file.duration_ms.to_i

        Verse.where(chapter: chapter).order('verse_index ASC').each do |verse|
          if segment = Audio::Segment.where(verse: verse, audio_recitation_id: recitation.id).first
            percentile = (segment.duration_ms.to_f / total_duration) * 100
            segment.update_column(:percentile, percentile.round(2))
          end
        end

        percentiles = []
        0.upto(100) do |i|
          timestamp = (i.to_f / 100) * total_duration
          file_segments = Audio::Segment.where(chapter_id: chapter.id, audio_recitation_id: recitation).order('verse_number ASC')
          segment = find_closest_segment(file_segments, timestamp)

          percentiles.push segment.verse_key
        end

        audio_file.timing_percentiles = percentiles
        audio_file.save(validate: false)
      end
    end

    def find_closest_segment(segments, time)
      closest_segment = segments[0]
      closest_diff = (closest_segment.timestamp_median - time).abs

      segments.each do |segment|
        diff = (segment.timestamp_median - time).abs

        if closest_diff >= diff && time > closest_segment.timestamp_to
          closest_diff = diff
          closest_segment = segment
        end
      end

      closest_segment
    end

    def update_audio_stats
      files_count = Audio::ChapterAudioFile.where(audio_recitation: recitation).size
      segments_count = Audio::Segment.where(audio_recitation: recitation).size

      recitation.update files_count: files_count, segments_count: segments_count
    end

    def import_timing_for_verse(verse, verse_data, next_verse_data, recitation)
      segment = Audio::Segment.where(
        verse_id: verse.id,
        audio_recitation_id: recitation.id,
        audio_file_id: find_or_create_audio_file(verse, recitation).id
      ).first_or_initialize

      words = verse_data.words
      segments = words.split(',').map do |time|
        time.split(':').map &:to_i
      end

      from = verse_data.start_time

      if verse_data.respond_to?('end_time')
        to = verse_data.end_time.presence
      end

      to ||= next_verse_data ? next_verse_data.start_time - 1 : (segments.last[2]).abs

      segment.set_timing(from, to, verse)
      segment.update_segments(segments)
    end

    def find_or_create_audio_file(verse, recitation)
      file = Audio::ChapterAudioFile.where(
        chapter_id: verse.chapter_id,
        audio_recitation_id: recitation.id
      ).first_or_initialize

      file.save(validate: false) if file.new_record?
      file
    end

    def fix_db_column_names
      table_name = self.class.table_name
      db = self.class.connection
      columns = self.class.column_names.map(&:downcase)

      if columns.include? 'timestart'
        db.execute("ALTER TABLE #{table_name} RENAME COLUMN timestart TO start_time")
      end

      if columns.include? 'time'
        db.execute("ALTER TABLE #{table_name} RENAME COLUMN time TO start_time")
      end

      if columns.include? 'timeend'
        db.execute("ALTER TABLE #{table_name} RENAME COLUMN timeend TO end_time")
      end

      if columns.include? 'wordtiming'
        db.execute("ALTER TABLE #{table_name} RENAME COLUMN wordtiming TO words")
      end

      self.class.reset_column_information
    end
  end
end