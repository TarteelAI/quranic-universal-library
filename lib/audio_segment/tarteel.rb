require 'sqlite3'

module AudioSegment
  class Tarteel
    STORAGE_PATH = "#{Rails.root}/tmp/exported_segments"
    DB_COLUMNS = ['label', 'reciter', 'surah_number', 'ayah_number', 'timings'].join(',')

    attr_reader :issues,
                :file_path,
                :table_name,
                :recitations

    def initialize(file_name:, table_name:, recitations_ids:)
      @issues = []
      @file_path = prepare_file_paths(file_name)
      @table_name = table_name.gsub(/[^0-9a-z_]/i, '_').gsub('__', '_').first(40)
      @recitations = load_recitations(recitations_ids)
    end

    def export
      db = prepare_db

      recitations.each do |recitation|
        export_recitation(recitation, db)
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

        @issues.push "#{recitation.tarteel_key} segments are missing for following ayahs: #{missing_ayahs.join(', ')}"
      end
    end

    def export_recitation(recitation, db)
      data = get_segments_data(recitation)

      placeholders = data.map { "(?, ?, ?, ?, ?)" }.join(", ")
      db.execute("INSERT INTO #{table_name} (#{DB_COLUMNS}) VALUES #{placeholders}", data.flatten)
    end

    def get_segments_data(recitation)
      tarteel_key = recitation.tarteel_key
      audio_files = recitation.audio_files.order("verse_id ASC")

      audio_files.map do |file|
        segments = file.get_segments

        segments.each_with_index do |segment, i|
          if segment.length != 3
            @issues.push("#{tarteel_key} #{file.chapter_id}:#{file.verse_number} length of #{i + 1} segment is wrong")
          end
        end

        if segments.size < file.verse.words_count
          @issues.push("#{tarteel_key} #{file.chapter_id}:#{file.verse_number} don't have segments for all words. Words count: #{file.verse.words_count} Segments count: #{segments.size}")
        end

        [
          tarteel_key,
          recitation.id,
          file.chapter_id,
          file.verse_number,
          segments.to_s.gsub(/\s+/, '')
        ]
      end
    end

    def prepare_db
      db = SQLite3::Database.new(file_path)
      db.execute("CREATE TABLE #{table_name}(label STRING, reciter INTEGER, surah_number INTEGER, ayah_number INTEGER, timings TEXT)")

      db
    end

    def load_recitations(ids)
      if ids == ['tarteel-reciters']
        tag = Tag.where(name: 'Tarteel recitation').first_or_create
        resources = ResourceContent
                      .recitations
                      .one_verse
                      .joins(:resource_tags)
                      .where(resource_tags: { tag_id: tag.id })

        Recitation.where(resource_content: resources)
      else
        Recitation.where(id: ids.map(&:to_i))
      end
    end

    def prepare_file_paths(file_name)
      file_path = "#{STORAGE_PATH}/#{Time.now.to_i}"
      FileUtils::mkdir_p file_path

      "#{file_path}/#{file_name}"
    end
  end
end