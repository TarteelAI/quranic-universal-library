require 'sqlite3'
require 'zip'
require 'fileutils'
require 'json'

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

    # Export segments data as JSON files(one file per surah) and create a master zip
    def export_json_files
      file_label = File.basename(file_path, File.extname(file_path))

      root_tmp = File.join(File.dirname(file_path), "json_export_#{Time.now.to_i}")
      FileUtils.mkdir_p(root_tmp)

      recitations.each do |recitation|
        reciter_dir = File.join(root_tmp, file_label, recitation.id.to_s)
        FileUtils.mkdir_p(reciter_dir)

        export_gapless_recitation_segments(recitation, reciter_dir)
        export_gapless_recitation_audio_files(recitation, reciter_dir)
      end

      master_zip = "#{file_path}.zip"
      Zip::File.open(master_zip, Zip::File::CREATE) do |zipfile|
        Dir[File.join(root_tmp, '**', '**')].each do |f|
          next if File.directory?(f)
          entry = f.sub("#{root_tmp}/", '')
          zipfile.add(entry, f)
        end
      end

      FileUtils.rm_rf(root_tmp)
      master_zip
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
        segments = get_ayah_segments(file)

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
                     audio_recitation_id: recitation.id
                   )
                   .order('chapter_id ASC, verse_number ASC')
                   .includes(:verse)

      segments.map do |segment|
        ayah_segments = get_ayah_segments(segment)
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

    def export_gapless_recitation_segments(recitation, target_dir)
      segments = Audio::Segment
                   .where(audio_recitation_id: recitation.id)
                   .order('chapter_id ASC, verse_number ASC')
                   .includes(:verse)

      grouped = segments.group_by(&:chapter_id)
      all_segments = {}
      uploader = UploadToCdn.new

      grouped.each do |chapter_id, segs|
        json_ayahs = []
        last_ayah_end = nil

        segs.each do |seg|
          ayah_segments = get_ayah_segments(seg)
          verse = seg.verse

          ayah_segments.each_with_index do |s, i|
            if s.length != 3
              @issues.push("Recitation: #{recitation.id} ayah #{chapter_id}:#{verse.verse_number} length of #{i + 1} segment is wrong")
            end
          end

          if ayah_segments.size < verse.words_count
            @issues.push("Recitation: #{recitation.id} ayah #{chapter_id}:#{verse.verse_number} don't have segments for all words. Words count: #{verse.respond_to?(:words_count) ? verse.words_count : 'unknown'} Segments count: #{ayah_segments.size}")
          end

          start_time = if last_ayah_end
                          last_ayah_end + 1
                        else
                          seg.timestamp_from.to_i
                       end

          json_ayahs << {
            ayah: verse.verse_number,
            start: start_time,
            end: seg.timestamp_to.to_i,
            words: ayah_segments
          }

          last_ayah_end = seg.timestamp_to.to_i
        end

        json_filename = format("%03d.json", chapter_id)
        json_path = File.join(target_dir, json_filename)

        File.open(json_path, "w") do |f|
          f.write(JSON.dump(json_ayahs))
        end

        all_segments[chapter_id] = json_ayahs

        key = "audio/gapless/#{recitation.get_resource_content.id}/#{chapter_id}.json"
        uploader.upload(json_path, key)

        json_path
      end

      full_segments_file_path = File.join(target_dir, "all_segments.json")

      File.open(full_segments_file_path, "w") do |f|
        f.write(JSON.dump(all_segments))
      end

      key = "audio/gapless/#{recitation.get_resource_content.id}/segments.json"
      uploader.upload(full_segments_file_path, key)
    end

    def export_gapless_recitation_audio_files(recitation, target_dir)
      audio_files = recitation.chapter_audio_files.order('chapter_id ASC')

      json_data = audio_files.map do |audio_file|
        {
          surah: audio_file.chapter_id,
          version: audio_file.updated_at.to_i,
          url: audio_file.audio_url
        }
      end

      json_filename = "audio_files.json"
      json_path = File.join(target_dir, json_filename)

      File.open(json_path, "w") do |f|
        f.write(JSON.dump(json_data))
      end

      uploader = UploadToCdn.new
      key = "audio/gapless/#{recitation.get_resource_content.id}/audio_files.json"
      uploader.upload(json_path, key)

      json_path
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

    def get_ayah_segments(seg)
      seg.get_segments(drop_metadata: true)
    end
  end
end
