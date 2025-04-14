namespace :segments do
  task prepare_audio: :environment do
    require 'thread'
    MAX_CONCURRENT_DOWNLOADS = 10
    MAX_CONCURRENT_ENCODES = 5

    recitation = Audio::Recitation.find(168)
    base_path = "tmp/audio/#{recitation.id}"
    surah_audio_path = "#{base_path}/surah/mp3"
    surah_audio_wav_path = "#{base_path}/surah/wav"

    FileUtils.mkdir_p("#{base_path}/vs_logs")
    FileUtils.mkdir_p("#{base_path}/results")

    FileUtils.mkdir_p(surah_audio_path)
    FileUtils.mkdir_p(surah_audio_wav_path)

    def download_audio(url, destination_file)
      if File.exist?(destination_file)
        puts "#{destination_file} already exists"
      else
        uri = URI(url)
        Net::HTTP.version_1_2 # make sure we use higher HTTP protocol version than 1.0

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        response = http.get(url)
        File.open(destination_file, "wb") do |file|
          file << response.body
        end

        puts "Downloaded #{url} to #{destination_file}"
      end
    end

    def encode_to_wave(mp3_path, wav_path)
      if File.exist?(wav_path)
        puts "#{wav_path} already exists"
        return
      end

      puts "Encoding #{mp3_path} to #{wav_path}"
      `ffmpeg -i #{mp3_path} -ac 1 -ar 16000 -c:a pcm_s16le #{wav_path}`
    end

    queue = Queue.new
    threads = []

    recitation.chapter_audio_files.order('chapter_id ASC').each do |audio_file|
      queue << audio_file
    end

    5.times do
      # Use 5 threads to download and encode audio in parallel
      threads << Thread.new do
        while !queue.empty?
          audio_file = queue.pop(true) rescue nil
          next unless audio_file

          file_url = audio_file.audio_url
          mp3_path = "#{surah_audio_path}/#{audio_file.chapter_id}.mp3"
          wav_path = "#{surah_audio_wav_path}/#{audio_file.chapter_id}.wav"

          puts "Downloading: #{file_url}"
          download_audio(file_url, mp3_path)

          puts "Encoding: #{mp3_path}"
          encode_to_wave(mp3_path, wav_path)
        end
      end
    end

    threads.each(&:join)
    puts "All audio files are downloaded and encoded to wav, see #{surah_audio_wav_path}"
  end

  task prepare_segments: :environment do
    require 'sqlite3'
    require 'json'
    require 'fileutils'

    recitation = Audio::Recitation.find(168)
    base_path = "tmp/audio/#{recitation.id}"

    MUSHAF_TRANSLATOR_INDEX = Oj.load(File.read("lib/data/mushaf-translator-index.json"))

    def create_db(base_path, db_name)
      db = SQLite3::Database.new "#{base_path}/#{db_name}.db"
      db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS timings (
      sura TEXT,
      ayah TEXT,
      start_time TEXT,
      end_time TEXT,
      words TEXT
    );
      SQL

      db
    end

    def insert_segment(db, surah_number, ayah_number, words)
      start_time = words[0][1].to_s
      end_time = words[-1][2].to_s
      words = JSON.dump(words)

      stmt = db.prepare("INSERT INTO timings (sura, ayah, start_time, end_time, words) VALUES (?, ?, ?, ?, ?)")
      stmt.bind_params(surah_number, ayah_number, start_time, end_time, words)
      stmt.execute
      stmt.close
    end

    def translate_word(surah, ayah, word)
      surah_mapping = MUSHAF_TRANSLATOR_INDEX[surah.to_s]
      if surah_mapping && surah_mapping[ayah.to_s]
        word_id = word.to_i - 1
        val = surah_mapping[ayah.to_s][word_id.to_s]

        val ? val.to_i + 1 : word
      else
        word
      end
    end

    def merge_ayah_segments(ayah_segments)
      surah = ayah_segments[:surah]
      ayah  = ayah_segments[:ayah]
      words = ayah_segments[:words]

      words_timing = []

      words.each_with_index do |current_word, _i|
        current_word[0] = translate_word(surah, ayah, current_word[0])

        if words_timing.empty?
          words_timing << current_word
        else
          last_word = words_timing.last

          if current_word[0] == last_word[0] # same word
            words_timing[-1] = [
              current_word[0], # Word number
              last_word[1], # Start Time
              current_word[2] # End time
            ]
          else
            words_timing << current_word
          end
        end
      end

      ayah_segments[:words] = words_timing
      ayah_segments
    end

    def process_surah_time_machine(segments_file)
      entries = Oj.load(File.read(segments_file))
      ayah_groups = Hash.new { |h, k| h[k] = [] }

      entries.each do |entry|
        case entry['type']
        when 'POSITION'
          position = entry['position']
          position.blank? && next

          surah = position['surahNumber']
          ayah = position['ayahNumber']
          word_number = position['wordNumber']
          start_time = entry['startTime']
          end_time = entry['endTime']

        when 'FAILURE'
          mistake = entry['mistakeWithPositions']
          if mistake.blank? || mistake['positions'].blank?
            next
          end

          position_data = mistake['positions'].first
          surah = position_data['surahNumber']
          ayah = position_data['ayahNumber']
          word_number = position_data['wordIndex'].to_i + 1
          start_time = entry['startTime']
          end_time = entry['endTime']
        else
          next
        end

        ayah_groups[[surah, ayah]] << {
          word_number: word_number,
          start_time: start_time,
          end_time: end_time
        }
      end

      result = []
      ayah_groups.each do |(surah, ayah), words|
        adjusted_words = []
        previous_end = nil

        words.each do |word|
          adjusted_start = previous_end || word[:start_time]

          adjusted_words << {
            word_number: word[:word_number],
            start_time: adjusted_start,
            end_time: word[:end_time]
          }

          previous_end = word[:end_time]
        end

        result << {
          surah: surah,
          ayah: ayah,
          start_time: adjusted_words.first[:start_time],
          end_time: adjusted_words.last[:end_time],
          words: adjusted_words.map { |w| [w[:word_number], w[:start_time], w[:end_time]] }
        }
      end

      result.sort_by! { |a| [a[:surah], a[:ayah]] }
      result
    end

    def process_segments(file_path)
      file_data = File.read(file_path)
      segments = JSON.parse(file_data)

      segments.each do |segment|
        data = merge_ayah_segments(segment)
        ayah_number = data["ayah"].to_i
        words = data['words']
        insert_segment(db, surah_number, ayah_number, words)
      end
    end

    export_path = "#{base_path}/results"
    FileUtils.mkdir_p(export_path)
    FileUtils.mkdir_p("#{export_path}/json")

    db = create_db(export_path, 'segments')

    Dir.glob("#{base_path}/vs_logs/**/time-machine.json") do |file_path|
      segments = process_surah_time_machine(file_path)
      json_data = {}
      surah = segments[0][:surah]

      segments.each do |segment|
        segment = merge_ayah_segments(segment)

        surah_number = segment[:surah]
        ayah_number = segment[:ayah]
        words = segment[:words]
        json_data[ayah_number] = words

        insert_segment(db, surah_number, ayah_number, words)
      end

      File.open("#{export_path}/json/#{surah}.json", 'w') do |f|
        f.puts json_data.to_json
      end
    end
  end
end