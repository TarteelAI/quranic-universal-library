module AudioSegment
  class AyahByAyah
    attr_reader :recitation

    def initialize(recitation)
      @recitation = recitation
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

    def import(remove_existing: false)
      # TODO: implement this
    end

    protected

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