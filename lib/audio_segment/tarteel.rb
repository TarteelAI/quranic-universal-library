require 'sqlite3'

module AudioSegment
  class Tarteel
    STORAGE_PATH = "#{Rails.root}/tmp/exported_segments"
    DB_COLUMNS = ['reciter', 'surah_number', 'ayah_number', 'timings'].join(',')
    GAPLESS_DB_COLUMNS = ['reciter', 'surah_number', 'ayah_number', 'start_time', 'end_time', 'timings'].join(',')

    attr_reader :issues,
                :file_path,
                :table_name,
                :recitations,
                :gapless

    def initialize(file_name:, table_name:, recitations_ids:, gapless: false)
      @gapless = gapless
      @issues = []
      @file_path = prepare_file_paths(file_name)
      @table_name = table_name.gsub(/[^0-9a-z_]/i, '_').gsub('__', '_').first(40)
      @recitations = load_recitations(recitations_ids)
    end

    def export
      db = prepare_db

      recitations.each do |recitation|
        if gapless
          export_gapless_recitation(recitation, db)
        else
          export_recitation(recitation, db)
        end

        validate_segments(recitation, db)
      end

      db.close

      file_path
    end

    protected

    def validate_segments(recitation, db)
      segments_count = db.get_first_value("SELECT COUNT(*) FROM #{table_name} WHERE reciter = ?", recitation.id)

      if segments_count != 6236
        segments = db.execute("SELECT surah_number, ayah_number FROM #{table_name} WHERE reciter = ?", recitation.id)
        missing_ayahs = Verse.pluck(:verse_key) - segments.map { |row| "#{row[0]}:#{row[1]}" }

        @issues.push "Recitation: #{recitation.id} segments are missing for following ayahs: #{missing_ayahs.join(', ')}"
      end
    end

    def export_recitation(recitation, db)
      data = get_segments_data(recitation)

      placeholders = data.map { "(?, ?, ?, ?)" }.join(", ")
      db.execute("INSERT INTO #{table_name} (#{DB_COLUMNS}) VALUES #{placeholders}", data.flatten)
    end

    def export_gapless_recitation(recitation, db)
      data = get_gapless_segments_data(recitation)

      data.each do |row|
        db.execute("INSERT INTO #{table_name} (#{GAPLESS_DB_COLUMNS}) VALUES (?, ?, ?, ?, ?, ?)", row.flatten)
      end
    end

    def get_segments_data(recitation)
      audio_files = recitation.audio_files.order("verse_id ASC")

      audio_files.map do |file|
        segments = file.get_segments

        segments.each_with_index do |segment, i|
          if segment.length != 3
            @issues.push("Recitation: #{recitation.id} ayah #{file.chapter_id}:#{file.verse_number} length of #{i + 1} segment is wrong")
          end
        end

        if segments.size < file.verse.words_count
          @issues.push("Recitation: #{recitation.id} ayah #{file.chapter_id}:#{file.verse_number} don't have segments for all words. Words count: #{file.verse.words_count} Segments count: #{segments.size}")
        end

        [
          recitation.id,
          file.chapter_id,
          file.verse_number,
          segments.to_s.gsub(/\s+/, '')
        ]
      end
    end

    def get_gapless_segments_data(recitation)
      segments = Audio::Segment
                   .where(
                     audio_recitation: recitation
                   )
                   .order('chapter_id ASC, verse_number ASC')
                   .includes(:verse)

      segments.map do |segment|
        ayah_segments = segment.get_segments
        verse = segment.verse

        ayah_segments.each_with_index do |segment, i|
          if segment.length != 3
            @issues.push("Recitation: #{recitation.id} ayah #{verse.chapter_id}:#{verse.verse_number} length of #{i + 1} segment is wrong")
          end
        end

        if ayah_segments.size < verse.words_count
          @issues.push("Recitation: #{recitation.id} ayah #{verse.chapter_id}:#{verse.verse_number} don't have segments for all words. Words count: #{verse.words_count} Segments count: #{ayah_segments.size}")
        end

        [
          recitation.id,
          verse.chapter_id,
          verse.verse_number,
          segment.timestamp_from,
          segment.timestamp_to,
          ayah_segments.to_s.gsub(/\s+/, '')
        ]
      end
    end

    def prepare_db
      if gapless
        db = SQLite3::Database.new(file_path)
        db.execute("CREATE TABLE #{table_name}(reciter INTEGER, surah_number INTEGER, ayah_number INTEGER, start_time, end_time, timings TEXT)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_reciter_surah_ayah ON #{table_name} (reciter, surah_number, ayah_number)")
      else
        db = SQLite3::Database.new(file_path)
        db.execute("CREATE TABLE #{table_name}(reciter INTEGER, surah_number INTEGER, ayah_number INTEGER, timings TEXT)")
        db.execute("CREATE INDEX IF NOT EXISTS idx_reciter_surah_ayah ON #{table_name} (reciter, surah_number, ayah_number)")
      end

      db
    end

    def load_recitations(ids)
      if ids == ['tarteel-reciters']
        tag = Tag.where(name: 'Tarteel recitation').first_or_create

        if gapless
          resources = ResourceContent
                        .recitations
                        .one_chapter
                        .joins(:resource_tags)
                        .where(resource_tags: { tag_id: tag.id })

          Audio::Recitation.where(resource_content_id: resources.pluck(:id))
        else
          resources = ResourceContent
                        .recitations
                        .one_verse
                        .joins(:resource_tags)
                        .where(resource_tags: { tag_id: tag.id })

          Recitation.where(resource_content: resources)
        end
      else
        if gapless
          Audio::Recitation.where(id: ids.map(&:to_i))
        else
          Recitation.where(id: ids.map(&:to_i))
        end
      end
    end

    def prepare_file_paths(file_name)
      file_path = "#{STORAGE_PATH}/#{Time.now.to_i}"
      FileUtils::mkdir_p file_path

      "#{file_path}/#{file_name}"
    end
  end
end