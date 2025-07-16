module AudioSegment
  class TimingTable < ActiveRecord::Base
    self.table_name = 'timings'
  end

  class AyahByAyah
    attr_reader :recitation

    def initialize(recitation)
      @recitation = recitation
    end

    def self.import(args)
      recitation_id = args[:recitation_id]
      file_path = args[:file_path]
      remove_existing = args[:remove_existing]

      segment = AudioSegment::AyahByAyah.new(Recitation.find(recitation_id))

      segment.import(
        file_path: file_path,
        remove_existing: remove_existing
      )
    end

    def import(file_path:, remove_existing: false)
      db_file = file_path
      AudioFile.where(recitation_id: recitation.id).delete_all if remove_existing

      if File.extname(file_path) == '.csv'
        csv_to_db = Utils::CsvToSqlite3.new(file_path)
        db_file = csv_to_db.convert(db_file)
      end

      TimingTable.establish_connection({
                                         adapter: 'sqlite3',
                                         database: db_file
                                       })

      Verse.unscoped.order('verse_index ASC').find_each do |verse|
        verse_segment = TimingTable.where(
          sura: verse.chapter_id,
          ayah: verse.verse_number
        ).first
        next if verse_segment.blank?

        import_verse_segments(verse, verse_segment)
      end

      update_audio_stats
    end

    def export(format, chapter_id = nil)
      audio_files = AudioFile.where(recitation_id: recitation.id).order('verse_id asc')

      if chapter_id.present?
        audio_files = audio_files.where(chapter_id: chapter_id)
      end

      file_path = "#{Rails.root}/tmp/segments_#{recitation.id}.#{format}"
      FileUtils.rm(file_path) if File.exist?(file_path)

      if format == 'db'
        export_sqlite_db(audio_files, file_path)
      else
        export_json(audio_files, file_path)
      end

      file_path
    end

    def track_repetition(chapter_id: nil)
      audio_files = AudioFile.where(recitation_id: recitation.id).order('verse_id asc')

      if chapter_id
        audio_files = audio_files.where(chapter_id: chapter_id)
      end

      audio_files.each do |audio_file|
        next if audio_file.segments.blank?

        repetition = audio_file.find_repeated_segments

        audio_file.update_columns(
          has_repetition: repetition.present?,
          repeated_segments: repetition.to_s
        )
      end
    end

    protected
    def update_audio_stats
      recitation.update_audio_stats
    end

    def import_verse_segments(verse, verse_segment)
      audio_file = AudioFile.where(
        recitation_id: recitation.id,
        verse_id: verse.id
      ).first_or_initialize

      audio_file.chapter_id = verse.chapter_id
      audio_file.hizb_number = verse.hizb_number
      audio_file.juz_number = verse.juz_number
      audio_file.manzil_number = verse.manzil_number
      audio_file.verse_number = verse.verse_number
      audio_file.page_number  = verse.page_number
      audio_file.rub_el_hizb_number = verse.rub_el_hizb_number
      audio_file.ruku_number = verse.ruku_number
      audio_file.verse_key = verse.verse_key

      audio_file.url ||= verse_segment.audio_url
      audio_file.format ||= recitation.audio_format
      audio_file.is_enabled = true
      audio_file.set_segments(JSON.parse(verse_segment.words))
      audio_file.save(validate: false)
    end

    def export_sqlite_db(audio_files, file_path)
      db = SQLite3::Database.new(file_path)
      table_name = 'timings'

      columns = ['sura', 'ayah', 'audio_url', 'words']
      create_table_sql = "CREATE TABLE IF NOT EXISTS #{table_name} (#{columns.map { |c| "#{c} TEXT" }.join(', ')});"
      db.execute(create_table_sql)

      insert_sql = "INSERT INTO #{table_name} (#{columns.join(', ')}) VALUES (#{columns.map { '?' }.join(', ')});"
      insert_statement = db.prepare(insert_sql)

      audio_files.each do |audio_file|
        surah = audio_file.chapter_id
        ayah = audio_file.verse_number

        data = [
          surah.to_s,
          ayah.to_s,
          audio_file.audio_url,
          audio_file.segment_data
        ]

        insert_statement.execute(data)
      end

      insert_statement.close
      db.close
    end

    def export_json(audio_files, file_path)
      columns = ['sura', 'ayah', 'audio_url', 'words']

      CSV.open(file_path, "wb") do |csv|
        csv << columns

        audio_files.each do |audio_file|
          surah = audio_file.chapter_id
          ayah = audio_file.verse_number

          data = [
            surah,
            ayah,
            audio_file.audio_url,
            audio_file.segment_data
          ]

          csv << data
        end
      end
    end
  end
end