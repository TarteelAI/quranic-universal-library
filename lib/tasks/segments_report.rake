namespace :segments_report do
  task parse_logs: :environment do
    base_path = "/Volumes/Data/qul-segments/15-july"
    logs_path = "#{base_path}/logs/*.log"
    DB_FILE = "#{base_path}/segments_database.db"

    class SegmentBase < ActiveRecord::Base
      self.abstract_class = true
      self.establish_connection(
        adapter: 'sqlite3',
        database: DB_FILE
      )
    end

    class SegmentLog < SegmentBase
      self.table_name = 'logs'
    end

    Dir.glob(logs_path).each do |file_path|
      puts "Processing #{file_path}"

      content = File.readlines(file_path)
      next if content.blank?

      filename = File.basename(file_path)
      reciter_id = filename[0..3].to_i
      surah_number = filename[4..7].to_i

      content.each do |line|
        match = line.match(/^\[(.*?)\]\s*(.*)/)
        time = match[1]
        time = Time.iso8601(time)

        if (log = match[2].to_s.strip).present?
          SegmentLog.create(
            surah_number: surah_number,
            reciter_id: reciter_id,
            timestamp: time.to_i,
            log: log
          )
        end
      end
    end
  end

  task prepare_stats: :environment do
    require 'sqlite3'

    base_path = "/Volumes/Data/qul-segments/15-july"
    logs_path = "#{base_path}/vs_logs/**/time-machine.json"
    DB_FILE = "#{base_path}/segments_data.db"

    recitation_ids = []

    Dir.glob(logs_path) do |file_path|
      session_id = file_path[%r{vs_logs/([^/]+)/}, 1]
      reciter_id = session_id[0..3].to_i
      recitation_ids << reciter_id
    end

    recitations = Audio::Recitation.where(id: recitation_ids.uniq)

    class Stats < ActiveRecord::Base
      self.abstract_class = true
      self.establish_connection(
        adapter: 'sqlite3',
        database: DB_FILE
      )
    end

    class DetectionStat < Stats
      self.table_name = 'detection_stats'
    end

    class Position < Stats
      self.table_name = 'positions'
    end

    class Failure < Stats
      self.table_name = 'failures'
    end

    class ReciterName < Stats
      self.table_name = 'reciters'
    end

    unless Stats.connection.tables.include?("reciters")
      Stats.connection.create_table :reciters do |t|
        t.string :name
        t.string :audio_cdn_path
        t.boolean :prefix_file_name, default: false
      end
    end

    unless Stats.connection.tables.include?("positions")
      Stats.connection.create_table :positions do |t|
        t.integer :surah_number
        t.integer :ayah_number
        t.integer :word_number
        t.string :word_key
        t.integer :reciter_id
        t.integer :start_time
        t.integer :end_time
      end
    end

    unless Stats.connection.tables.include?("detection_stats")
      Stats.connection.create_table :detection_stats do |t|
        t.integer :surah_number
        t.integer :reciter_id
        t.string :detection_type
        t.integer :count
      end
    end

    unless Stats.connection.tables.include?("failures")
      Stats.connection.create_table :failures do |t|
        t.integer :surah_number
        t.integer :ayah_number
        t.integer :word_number
        t.string :word_key
        t.string :text
        t.integer :reciter_id
        t.string :failure_type
        t.string :received_transcript
        t.string :expected_transcript
        t.integer :start_time
        t.integer :end_time
      end
    end

    recitations.each do |recitation|
      resource_content = recitation.get_resource_content
      base_url = resource_content.meta_value("audio-cdn-url") || "https://download.quranicaudio.com"
      path = recitation.relative_path
      sample_audio_url = recitation.chapter_audio_files.where(chapter_id: 1).first.audio_url
      prefix_file_name = sample_audio_url.split('/').last.start_with?('00')

      ReciterName.where(id: recitation.id).first_or_create(
        name: recitation.name,
        audio_cdn_path: "#{base_url}/#{path}",
        prefix_file_name: prefix_file_name
      )
    end

    Dir.glob(logs_path) do |file_path|
      puts "Processing #{file_path}"

      filename = File.basename(File.dirname(file_path))
      next unless filename.match?(/^\d{8}-/)

      content = File.read(file_path)
      next if content.blank?

      reciter = filename[0..3].to_i
      surah = filename[4..7].to_i

      type_counts = Hash.new(0)
      data = JSON.parse(content)

      data.each do |entry|
        type = entry["type"]
        type_counts[type] += 1

        mistake = entry["mistakeWithPositions"]
        type_counts['FAILURE'] += 1 if mistake && type != 'FAILURE'

        next if mistake.blank?

        word_info = entry["position"] || entry["sessionRange"]
        ayah = word_info&.[]("ayahNumber") || word_info&.[]("startAyahNumber")
        word_num = word_info&.[]("wordNumber") || word_info&.[]("wordIndex")
        word_key = (ayah && word_num) ? "#{surah}:#{ayah}:#{word_num}" : "unknown"

        Failure.create!(
          surah: surah,
          ayah: ayah,
          word: word_num,
          reciter: reciter,
          word_key: word_key,
          text: entry['word'],
          failure_type: mistake["mistakeType"],
          received_transcript: mistake["receivedTranscript"],
          expected_transcript: mistake["expectedTranscript"],
          start_time: entry["startTime"],
          end_time: entry["endTime"]
        )
      end

      type_counts.each do |type, count|
        DetectionStat.create!(
          surah: surah,
          reciter: reciter,
          detection_type: type,
          count: count
        )
      end
    end

    puts "Log parsing finished ✅ — See: #{DB_FILE}"
  end

  task prepare_stats_updated: :environment do
    require 'sqlite3'

    base_path = "/Volumes/Data/qul-segments/15-july"
    logs_path = "#{base_path}/vs_logs/**/time-machine.json"
    DB_FILE = "#{base_path}/segments_database.db"

    recitation_ids = []

    Dir.glob(logs_path) do |file_path|
      session_id = file_path[%r{vs_logs/([^/]+)/}, 1]
      reciter_id = session_id[0..3].to_i
      recitation_ids << reciter_id
    end

    recitations = Audio::Recitation.where(id: recitation_ids.uniq)

    class SegmentBase < ActiveRecord::Base
      self.abstract_class = true
      self.establish_connection(
        adapter: 'sqlite3',
        database: DB_FILE
      )
    end

    class SegmentLog < SegmentBase
      self.table_name = 'logs'
    end

    class DetectionStat < SegmentBase
      self.table_name = 'detection_stats'
    end

    class Position < SegmentBase
      self.table_name = 'positions'
    end

    class Failure < SegmentBase
      self.table_name = 'failures'
    end

    class ReciterName < SegmentBase
      self.table_name = 'reciters'
    end

    unless SegmentBase.connection.tables.include?("reciters")
      SegmentBase.connection.create_table :reciters do |t|
        t.string :name
        t.string :audio_cdn_path
        t.boolean :prefix_file_name, default: false
      end
    end

    unless SegmentBase.connection.tables.include?("positions")
      SegmentBase.connection.create_table :positions do |t|
        t.integer :surah_number
        t.integer :ayah_number
        t.integer :word_number
        t.string :word_key
        t.integer :reciter_id
        t.integer :start_time
        t.integer :end_time
      end
    end

    unless SegmentBase.connection.tables.include?("detection_stats")
      SegmentBase.connection.create_table :detection_stats do |t|
        t.integer :surah_number
        t.integer :ayah_number
        t.integer :reciter_id
        t.string :detection_type
        t.integer :count
      end
    end

    unless SegmentBase.connection.tables.include?("logs")
      SegmentBase.connection.create_table :logs do |t|
        t.integer :surah_number
        t.integer :reciter_id
        t.integer :timestamp
        t.string :log
      end
    end

    unless SegmentBase.connection.tables.include?("failures")
      SegmentBase.connection.create_table :failures do |t|
        t.integer :surah_number
        t.integer :ayah_number
        t.integer :word_number
        t.string :word_key
        t.string :text
        t.integer :reciter_id
        t.string :failure_type
        t.string :received_transcript
        t.string :expected_transcript
        t.integer :start_time
        t.integer :end_time
      end
    end

    recitations.each do |recitation|
      resource_content = recitation.get_resource_content
      base_url = resource_content.meta_value("audio-cdn-url") || "https://download.quranicaudio.com"
      path = recitation.relative_path
      sample_audio_url = recitation.chapter_audio_files.where(chapter_id: 1).first.audio_url
      prefix_file_name = sample_audio_url.split('/').last.start_with?('00')

      ReciterName.where(id: recitation.id).first_or_create(
        name: recitation.name,
        audio_cdn_path: "#{base_url}/#{path}",
        prefix_file_name: prefix_file_name
      )
    end

    Dir.glob(logs_path) do |file_path|
      puts "Processing #{file_path}"

      filename = File.basename(File.dirname(file_path))
      next unless filename.match?(/^\d{8}-/)

      content = File.read(file_path)
      next if content.blank?

      reciter_id = filename[0..3].to_i
      surah_number = filename[4..7].to_i

      type_counts = Hash.new(0)
      data = JSON.parse(content)

      data.each do |entry|
        type = entry["type"]
        type_counts[type] += 1

        mistake = entry["mistakeWithPositions"]
        type_counts['FAILURE'] += 1 if mistake && type != 'FAILURE'

        word_info = entry["position"] || entry["sessionRange"]
        ayah_number = word_info&.[]("ayahNumber") || word_info&.[]("startAyahNumber")
        word_number = word_info&.[]("wordNumber") || word_info&.[]("wordIndex")
        word_key = (ayah_number && word_number) ? "#{surah_number}:#{ayah_number}:#{word_number}" : "unknown"

        if mistake.present?
          Failure.create!(
            surah_number: surah_number,
            ayah_number: ayah_number,
            word_number: word_number,
            reciter_id: reciter_id,
            word_key: word_key,
            text: entry['word'],
            failure_type: mistake["mistakeType"],
            received_transcript: mistake["receivedTranscript"],
            expected_transcript: mistake["expectedTranscript"],
            start_time: entry["startTime"],
            end_time: entry["endTime"]
          )
        end

        if ayah_number && word_number && entry["startTime"] && entry["endTime"]
          Position.create!(
            surah_number: surah_number,
            ayah_number: ayah_number,
            word_number: word_number,
            word_key: word_key,
            reciter_id: reciter_id,
            start_time: entry["startTime"],
            end_time: entry["endTime"]
          )
        end
      end

      type_counts.each do |type, count|
        DetectionStat.create!(
          surah_number: surah_number,
          reciter_id: reciter_id,
          detection_type: type,
          count: count
        )
      end
    end

    puts "Log parsing finished, see the result DB #{DB_FILE}"
  end
end