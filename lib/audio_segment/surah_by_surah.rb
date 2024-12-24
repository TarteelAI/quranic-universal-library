module AudioSegment
  class TimingTable < ActiveRecord::Base
    self.table_name = 'timing'
  end

  class SurahBySurah
    attr_reader :recitation

    def initialize(recitation)
      @recitation = recitation
    end

    def export(format, chapter_id = nil)
      raise "Invalid export format, we only support csv, json and db formats" unless %w[csv json db].include?(format)

      segments = Audio::Segment
                   .where(
                     audio_recitation_id: recitation.id)
                   .order('verse_id asc')

      if chapter_id.present?
        segments = segments.where(chapter_id: chapter_id)
      end

      file_path = "#{Rails.root}/tmp/segments_#{recitation.id}.#{format}"
      FileUtils.rm(file_path) if File.exist?(file_path)

      if format == 'db'
        export_sqlite(segments, file_path)
      elsif format == 'json'
        export_json(segments, file_path)
      else
        export_csv(segments, file_path)
      end

      file_path
    end

    def self.import(recitation_id:, file_path:, remove_existing: false)
      segment = AudioSegment::SurahBySurah.new(Audio::Recitation.find(recitation_id))

      segment.import(
        file_path: file_path, remove_existing: remove_existing
      )
    end

    def import(file_path:, remove_existing: false)
      db_file = file_path
      Audio::Segment.where(audio_recitation_id: recitation.id).delete_all if remove_existing

      if File.extname(file_path) == '.csv'
        csv_to_db = Utils::CsvToSqlite3.new(file_path)
        db_file = csv_to_db.convert(db_file)
      end

      TimingTable.establish_connection({
                                         adapter: 'sqlite3',
                                         database: db_file
                                       })

      fix_timing_table_columns(TimingTable)

      Verse.unscoped.order('verse_index ASC').find_each do |verse|
        verse_segment = db.where(
          sura: verse.chapter_id,
          ayah: verse.verse_number
        ).first
        next if verse_data.blank?

        next_verse_segment = TimingTable.where(
          sura: verse.chapter_id,
          ayah: verse.verse_number + 1
        ).first

        import_verse_segments(verse, verse_segment, next_verse_segment)
      end

      update_audio_stats
      update_segment_percentile
    end

    def update_segment_percentile
      Chapter.find_each do |chapter|
        audio_file = Audio::ChapterAudioFile.where(
          audio_recitation_id: recitation.id,
          chapter_id: chapter.id
        ).first
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
          segment = find_closest_segment(chapter.id, timestamp)

          percentiles.push segment.verse_key
        end

        audio_file.timing_percentiles = percentiles
        audio_file.save(validate: false)
      end
    end

    def update_audio_stats
      files_count = Audio::ChapterAudioFile.where(audio_recitation: recitation).size
      segments_count = Audio::Segment.where(audio_recitation: recitation).size

      recitation.update(
        files_count: files_count,
        segments_count: segments_count
      )
    end

    def find_closest_segment(chapter_id, time)
      chapter_segments = Audio::Segment
                           .where(chapter_id: chapter_id, audio_recitation_id: recitation)
                           .order('verse_number ASC')

      closest_segment = chapter_segments[0]
      closest_diff = (closest_segment.timestamp_median - time).abs

      chapter_segments.each do |segment|
        diff = (segment.timestamp_median - time).abs

        if closest_diff >= diff && time > closest_segment.timestamp_to
          closest_diff = diff
          closest_segment = segment
        end
      end

      closest_segment
    end

    protected

    def import_verse_segments(verse, verse_segment, next_verse_segment)
      segment = Audio::Segment.where(
        verse_id: verse.id,
        audio_recitation_id: recitation.id,
        audio_file_id: find_or_create_audio_file(verse).id
      ).first_or_initialize

      words = verse_segment.words
      segments = words.split(',').map do |time|
        time.split(':').map &:to_i
      end

      from = verse_segment.start_time

      if verse_segment.respond_to?('end_time')
        to = verse_segment.end_time.presence
      end

      to ||= next_verse_segment ? next_verse_segment.start_time - 1 : (segments.last[2]).abs

      segment.set_timing(from, to, verse)
      segment.update_segments(segments)

      segment
    end

    def fix_timing_table_columns(db)
      columns = db.column_names.map(&:downcase)
      table_name = db.table_name
      connection = db.connection

      if columns.include? 'timestart'
        connection.execute("ALTER TABLE #{table_name} RENAME COLUMN timestart TO start_time")
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
    end

    def find_or_create_audio_file(verse)
      file = Audio::ChapterAudioFile.where(
        chapter_id: verse.chapter_id,
        audio_recitation_id: recitation.id
      ).first_or_initialize

      file.save(validate: false) if file.new_record?
      file
    end

    def export_sqlite(segments, file_path)
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
          segment.segments.to_s
        ]

        insert_statement.execute(data)
      end

      insert_statement.close
      db.close
    end

    def export_csv(segments, file_path)
      columns = ['sura', 'ayah', 'start_time', 'end_time', 'words']

      CSV.open(file_path, "wb") do |csv|
        csv << columns

        segments.each do |segment|
          data = [
            segment.chapter_id,
            segment.verse_number,
            segment.timestamp_from,
            segment.timestamp_to,
            segment.segments.to_s
          ]

          csv << data
        end
      end
    end

    def export_json(segments, file_path)
      data = {}
      segments.each do |segment|
        data["#{segment.chapter_id}:#{segment.verse_number}"] = {
          from: segment.timestamp_from,
          to: segment.timestamp_to,
          words: segment.segments.to_s
        }
      end

      File.open(file_path, "wb") do |csv|
        f << JSON.generate(data, { state: JsonNoEscapeHtmlState.new })
      end
    end
  end
end