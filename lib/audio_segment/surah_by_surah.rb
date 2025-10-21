module AudioSegment
  class TimingTable < ActiveRecord::Base
    self.table_name = 'timings'
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

    def self.import(args)
      recitation_id = args[:recitation_id]
      file_path = args[:file_path]
      remove_existing = args[:remove_existing]
      segment = AudioSegment::SurahBySurah.new(Audio::Recitation.find(recitation_id))

      segment.import(
        file_path: file_path,
        remove_existing: remove_existing
      )
    end

    def import(file_path:, remove_existing: false)
      db_file = file_path
      Audio::Segment.where(audio_recitation_id: recitation.id).delete_all if remove_existing

      if File.extname(file_path) == '.csv'
        csv_to_db = Utils::CsvToSqlite3.new(file_path)
        db_file = csv_to_db.convert("timings")
      end

      TimingTable.establish_connection({
                                         adapter: 'sqlite3',
                                         database: db_file
                                       })

      fix_timing_table_columns(TimingTable)

      Verse.unscoped.order('verse_index ASC').find_each do |verse|
        verse_segment = TimingTable.where(
          sura: verse.chapter_id,
          ayah: verse.verse_number
        ).first
        next if verse_segment.blank? || verse_segment.words.blank?

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
          if segment = find_closest_segment(chapter.id, timestamp)
            percentiles.push segment.verse_key
          end
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
      return if closest_segment.blank?

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

    def track_repetition(chapter_id: nil)
      segments = Audio::Segment.where(audio_recitation_id: recitation.id).order('verse_id asc')

      if chapter_id
        segments = segments.where(chapter_id: chapter_id)
      end

      segments.each do |segment|
        repetition = segment.find_repeated_segments

        segment.update_columns(
          has_repetition: repetition.present?,
          repeated_segments: repetition.to_s
        )
      end
    end

    def export_segments_positions(reciter_id, format = 'db')
      raise "Invalid export format, we only support csv, json and db formats" unless %w[csv json db].include?(format)

      positions = ::Segments::Position.where(reciter_id: reciter_id).order('surah_number, ayah_number')
      ayah_positions = positions.group_by { |pos| [pos.surah_number, pos.ayah_number] }
      ayah_boundaries = ::Segments::AyahBoundary.where(reciter_id: reciter_id).index_by { |b| [b.surah_number, b.ayah_number] }

      file_path = "#{Rails.root}/tmp/segments_positions_#{reciter_id}.#{format}"
      FileUtils.rm(file_path) if File.exist?(file_path)

      if format == 'db'
        export_segments_sqlite(ayah_positions, ayah_boundaries, file_path)
      elsif format == 'json'
        export_segments_json(ayah_positions, ayah_boundaries, file_path)
      else
        export_segments_csv(ayah_positions, ayah_boundaries, file_path)
      end

      file_path
    end
    protected

    def import_verse_segments(verse, verse_segment, next_verse_segment)
      audio_file = find_or_create_audio_file(verse)
      segment = Audio::Segment.where(
        verse_id: verse.id,
        audio_recitation_id: recitation.id,
        audio_file_id: audio_file.id
      ).first_or_initialize

      segments = Oj.load(verse_segment.words.to_s)
      from = verse_segment.start_time.to_i
      to = verse_segment.end_time.presence

      to ||= next_verse_segment ? next_verse_segment.start_time.to_i - 1 : (segments.last[2]).abs
      to = to.to_i

      if next_verse_segment
        next_ayah_start = next_verse_segment.start_time.to_i
        to = [to, next_ayah_start - 200].min
      end

      if verse.first_ayah?
        from = 0
        segments[0][1] = 0
      elsif verse.last_ayah?
        to = [to, audio_file.duration_ms.to_i].max
      end

      # Adjust last segment end time if it exceeds the verse end time
      segments[-1][2] = to

      segment.set_timing(from, to, verse)
      segment.set_segments!(segments)

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
        connection.execute("ALTER TABLE #{table_name} RENAME COLUMN time TO start_time")
      end

      if columns.include? 'timeend'
        connection.execute("ALTER TABLE #{table_name} RENAME COLUMN timeend TO end_time")
      end

      if columns.include? 'wordtiming'
        connection.execute("ALTER TABLE #{table_name} RENAME COLUMN wordtiming TO words")
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
          words: segment.segments
        }
      end

      File.open(file_path, "wb") do |csv|
        f << JSON.generate(data, { state: JsonNoEscapeHtmlState.new })
      end
    end
    private

    def export_segments_sqlite(ayah_positions, ayah_boundaries, file_path)
      db = SQLite3::Database.new(file_path)
      table_name = 'timings'

      columns = ['sura', 'ayah', 'start_time', 'end_time', 'words']
      create_table_sql = "CREATE TABLE IF NOT EXISTS #{table_name} (#{columns.map { |c| "#{c} TEXT" }.join(', ')});"
      db.execute(create_table_sql)

      insert_sql = "INSERT INTO #{table_name} (#{columns.join(', ')}) VALUES (#{columns.map { '?' }.join(', ')});"
      insert_statement = db.prepare(insert_sql)

      ayah_positions.each do |(surah, ayah), positions|
        timing_data = prepare_ayah_segments_data_for_export(surah, ayah, positions, ayah_boundaries)
        
        data = [
          timing_data[:surah],
          timing_data[:ayah],
          timing_data[:start_time],
          timing_data[:end_time],
          timing_data[:words].to_s
        ]

        insert_statement.execute(data)
      end

      insert_statement.close
      db.close
    end

    def export_segments_csv(ayah_positions, ayah_boundaries, file_path)
      columns = ['sura', 'ayah', 'start_time', 'end_time', 'words']

      CSV.open(file_path, "wb") do |csv|
        csv << columns

        ayah_positions.each do |(surah, ayah), positions|
          timing_data = prepare_ayah_segments_data_for_export(surah, ayah, positions, ayah_boundaries)
          
          data = [
            timing_data[:surah],
            timing_data[:ayah],
            timing_data[:start_time],
            timing_data[:end_time],
            timing_data[:words].to_s
          ]

          csv << data
        end
      end
    end

    def export_segments_json(ayah_positions, ayah_boundaries, file_path)
      data = {}
      
      ayah_positions.each do |(surah, ayah), positions|
        timing_data = prepare_ayah_segments_data_for_export(surah, ayah, positions, ayah_boundaries)
        
        data["#{timing_data[:surah]}:#{timing_data[:ayah]}"] = {
          from: timing_data[:start_time],
          to: timing_data[:end_time],
          words: timing_data[:words]
        }
      end

      File.open(file_path, "wb") do |f|
        f << JSON.generate(data, { state: JsonNoEscapeHtmlState.new })
      end
    end

    def prepare_ayah_segments_data_for_export(surah, ayah, positions, ayah_boundaries)
      boundary = ayah_boundaries[[surah, ayah]]
      
      start_time = boundary&.corrected_start_time || boundary&.start_time
      end_time = boundary&.corrected_end_time || boundary&.end_time
      
      if start_time.nil? || end_time.nil?
        sorted_positions = positions.sort_by(&:start_time)
        start_time ||= sorted_positions.first&.start_time
        end_time ||= sorted_positions.last&.end_time
      end
      
      words = positions.map do |pos|
        [
          pos.word_number,
          pos.corrected_start_time || pos.start_time,
          pos.corrected_end_time || pos.end_time
        ]
      end

      {
        surah: surah,
        ayah: ayah,
        start_time: start_time,
        end_time: end_time,
        words: words
      }
    end
  end
end