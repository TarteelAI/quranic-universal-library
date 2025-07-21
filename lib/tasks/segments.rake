namespace :segments do
  # With translations 39,
  def parse_chapter_ids(chapter_ids)
    chapter_ids = chapter_ids
                    .split(',')
                    .flat_map do |range|
      range = range.split('..').map(&:to_i)
      range << range.first if range.length == 1
      puts "Range: #{range}"
      Range.new(*range).to_a
    end

    chapter_ids.uniq
  end

  task prepare_audio: :environment do
    require 'thread'
    MAX_CONCURRENT_DOWNLOADS = 10
    MAX_CONCURRENT_ENCODES = 5

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

    recitations = Audio::Recitation.where.not(id: 171)
    chapter_ids = parse_chapter_ids("1,93..114")

    recitations.each do |recitation|
      base_path = "tmp/audio/#{recitation.id}"
      surah_audio_path = "#{base_path}/surah/mp3"
      surah_audio_wav_path = "#{base_path}/surah/wav"

      FileUtils.mkdir_p("#{base_path}/vs_logs")
      FileUtils.mkdir_p("#{base_path}/results")

      FileUtils.mkdir_p(surah_audio_path)
      FileUtils.mkdir_p(surah_audio_wav_path)

      queue = Queue.new
      threads = []
      audio_files = recitation
                      .chapter_audio_files
                      .order('chapter_id ASC')
                      .where(chapter_id: chapter_ids)

      audio_files.each do |audio_file|
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
            Dir["/Volumes/Data/qul-segments/audio/178/mp3/*.mp3"].each do |mp3_path|
              wav_path = mp3_path.gsub("mp3", "wav")
              encode_to_wave(mp3_path, wav_path)
            end
          end
        end
      end

      threads.each(&:join)
      puts "All audio files are downloaded and encoded to wav, see #{surah_audio_wav_path}"
    end
  end

  task generate_segments: :environment do
    recitations = Audio::Recitation.where(id: 167)
    chapter_ids = parse_chapter_ids("1,93..114")

    base_path = "/Volumes/Data/qul-segments/audio/vs_logs"
    FileUtils.mkdir_p(base_path)

    Dir.chdir('../voice-server') do
      recitations.each do |recitation|
        chapter_ids.each do |chapter_id|
          surah_index = chapter_id.to_s.rjust(4, '0')
          reciter_index = recitation.id.to_s.rjust(4, '0')
          session_prefix = "#{reciter_index}#{surah_index}"
          segment_session = Dir.glob("#{base_path}/#{session_prefix}-*/time-machine.json")

          if segment_session.present?
            puts "Skipping Reciter #{recitation.id}, Surah #{chapter_id} — already processed."
            next
          end

          puts "Generating segments for Reciter #{recitation.id}, Surah #{chapter_id}"
          system("pnpm generate:surahSegments --from #{chapter_id} --to #{chapter_id} --reciter #{recitation.id}")
        end
      end
    end
  end

  task parse_segments: :environment do
    require 'sqlite3'
    require 'json'
    require 'fileutils'

    MUSHAF_TRANSLATOR_INDEX = Oj.load(File.read("lib/data/mushaf-translator-index.json"))

    def create_db(base_path)
      db = SQLite3::Database.new "#{base_path}/segments.db"
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
      ayah = ayah_segments[:ayah]
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

    def normalize(text)
      text.remove_diacritics.tr('ًٌٍَُِّْـ', '')
    end

    def process_surah_time_machine(segments_file, surah_id)
      entries = Oj.load(File.read(segments_file))
      ayah_groups = Hash.new { |h, k| h[k] = [] }
      ayah_words = []
      last_word_index = 0
      
      words = Word
                .unscoped
                .where(
                  verse_id: Verse.where(chapter_id: surah_id, verse_number: [1, 2])
                )
                .includes(:verse)
                .order('word_index ASC')

      words.each do |word|
        ayah_words << {
            text_qpc_hafs: normalize(word.text_qpc_hafs),
            text_imlaei: normalize(word.text_imlaei),
            text_imlaei_simple: normalize(word.text_imlaei_simple),
            text_uthmani: normalize(word.text_uthmani),
            surah: word.chapter_id,
            ayah: word.verse.verse_number,
            word_number: word.position,
            matched: false
          }
      end

      entries.each do |entry|
        start_time = entry['startTime']
        end_time = entry['endTime']

        case entry['type']
        when 'POSITION'
          position = entry['position']
          position.blank? && next

          surah = position['surahNumber']
          ayah = position['ayahNumber']
          word_number = position['wordNumber']
        when 'FAILURE'
          mistake = entry['mistakeWithPositions']
          if mistake.blank? || mistake['positions'].blank?
            next
          end

          position_data = mistake['positions'].first
          surah = position_data['surahNumber']
          ayah = position_data['ayahNumber']
          word_number = position_data['wordIndex'].to_i + 1
        when 'IDENTIFYING'
          text = entry['word']&.strip
          next if text.blank?

          text = normalize(text)

          matched_word = ayah_words.find do |w|
            !w[:matched] &&
              [
                w[:text_qpc_hafs],
                w[:text_imlaei],
                w[:text_imlaei_simple],
                w[:text_uthmani]
              ].include?(text)
          end

          if matched_word
            surah = matched_word[:surah]
            ayah = matched_word[:ayah]
            word_number = matched_word[:word_number]
            matched_word[:matched] = true
          else
            next
          end
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

    base_path = "/Volumes/Data/qul-segments/15-july"
    reciter_databases = {}

    Dir.glob("#{base_path}/vs_logs/**/time-machine.json") do |file_path|
      puts "Processing #{file_path}"

      filename = File.basename(File.dirname(file_path))
      next unless filename.match?(/^\d{8}-/)
      content = File.read(file_path)
      next if content.blank?

      session_id = file_path[%r{vs_logs/([^/]+)/}, 1]

      reciter_id = session_id[0..3].to_i
      surah_id = session_id[4..7].to_i

      export_path = "#{base_path}/results/#{reciter_id}"
      FileUtils.mkdir_p("#{export_path}/json")

      reciter_databases[reciter_id] ||= create_db(export_path)
      db = reciter_databases[reciter_id]

      segments = process_surah_time_machine(file_path, surah_id)
      json_data = {}
      
      if segments.blank?
        puts "No segments found for #{file_path}"
        FileUtils.rm(file_path)
        next
      end
      
      surah = segments[0][:surah]
      binding.pry if @debug.nil?
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

  task prepare_stats: :environment do
    require 'sqlite3'
    base_path = "/Volumes/Data/qul-segments/15-july"
    logs_path = "#{base_path}/vs_logs/**/time-machine.json"

    DB_FILE =  "#{base_path}/segments_stats.db"
    recitation_ids = []

    Dir.glob(logs_path) do |file_path|
      session_id = file_path[%r{vs_logs/([^/]+)/}, 1]
      reciter_id = session_id[0..3].to_i
      recitation_ids << reciter_id
    end

    recitations = Audio::Recitation.where(id: recitation_ids)

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

    class Failure < Stats
      self.table_name = 'failures'
    end

    class ReciterName < Stats
      self.table_name = 'reciters'
    end

    if !Stats.connection.tables.include?("reciters")
      Stats.connection.create_table :reciters do |t|
        t.string :name
      end
    end

    if !Stats.connection.tables.include?("detection_stats")
      Stats.connection.create_table :detection_stats do |t|
        t.integer :surah
        t.integer :reciter
        t.string :detection_type
        t.integer :count
      end
    end

    if !Stats.connection.tables.include?("failures")
      Stats.connection.create_table :failures do |t|
        t.integer :surah
        t.integer :ayah
        t.integer :word
        t.string :word_key
        t.string :text
        t.integer :reciter
        t.string :failure_type
        t.string :received_transcript
        t.string :expected_transcript
        t.integer :start_time
        t.integer :end_time
      end
    end

    # Add reciter data
    recitations.each do |recitation|
      ReciterName
        .where(id: recitation.id)
        .first_or_create(
          name: recitation.name
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

        if mistake && type != 'FAILURE'
          type_counts['FAILURE'] += 1
        end

        next if mistake.blank?

        word_info = entry["position"] || entry.dig("sessionRange")
        word_key = if word_info
                     ayah = word_info["ayahNumber"] || word_info["startAyahNumber"]
                     word_num = word_info["wordNumber"] || word_info["wordIndex"]
                     "#{surah}:#{ayah}:#{word_num}"
                   else
                     "unknown"
                   end

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

    puts "Log parsing is finished. See #{DB_FILE}"
  end

  task generate_report: :environment do
    require 'sqlite3'
    base_path = "/Volumes/Data/qul-segments/15-july"
    DB_FILE =  "#{base_path}/segments_stats.db"
    output_file = "#{base_path}/report.html"

    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: DB_FILE)

    class DetectionStat < ActiveRecord::Base
      self.table_name = 'detection_stats'
    end

    class Failure < ActiveRecord::Base
    end

    detection_chart_data = {
      labels: DetectionStat.group(:detection_type).pluck(:detection_type),
      values: DetectionStat.group(:detection_type).sum(:count).values
    }

    mistake_type_chart_data = {
      labels: Failure.group(:failure_type).pluck(:failure_type),
      values: Failure.group(:failure_type).count.values
    }

    top_mistake_words_data = Failure
                               .group(:word_key)
                               .order('count_all DESC')
                               .limit(10)
                               .count
                               .to_a
                               .transpose

    top_mistake_words_data = {
      labels: top_mistake_words_data[0] || [],
      values: top_mistake_words_data[1] || []
    }

    reciter_mistake_ratio_data = Failure
                                   .group(:reciter)
                                   .count
                                   .map do |reciter, mistakes|
      total = DetectionStat.where(reciter: reciter).sum(:count).to_f
      [reciter.to_s, total.positive? ? ((mistakes / total) * 100).round(2) : 0]
    end.transpose

    reciter_mistake_ratio_data = {
      labels: reciter_mistake_ratio_data[0],
      values: reciter_mistake_ratio_data[1]
    }

    surah_mistake_ratio_data = Failure
                                 .group(:surah)
                                 .count
                                 .map do |surah, mistakes|
      total = DetectionStat.where(surah: surah).sum(:count).to_f
      [surah.to_s, total.positive? ? ((mistakes / total) * 100).round(2) : 0]
    end.transpose

    surah_mistake_ratio_data = {
      labels: surah_mistake_ratio_data[0],
      values: surah_mistake_ratio_data[1]
    }

=begin
    # Top expected → received pairs
    top_expected = Failure
                     .group(:expected_transcript, :received_transcript)
                     .count
                     .group_by { |(expected, _), _| expected }
                     .transform_values do |arr|
      arr.map { |(expected, received), count| [received, count] }.to_h
    end

    top_expected = top_expected
                     .sort_by { |_, v| -v.values.sum }
                     .take(50).to_h
=end

    top_expected = Failure
                     .group(:expected_transcript, :received_transcript, :failure_type)
                     .count
                     .group_by { |(expected, _, _), _| expected }
                     .transform_values do |arr|
      arr.each_with_object({}) do |((_, received, type), count), hash|
        hash[received] = { count: count, type: type }
      end
    end

    top_expected = top_expected
                     .sort_by { |_, v| -v.values.sum { |data| data[:count] } }
                     .take(50)
                     .to_h

    # Render HTML
    template = <<~HTML
                  <!DOCTYPE html>
                  <html>
                  <head>
                    <meta charset="utf-8" />
                    <title>Audio Stats Report</title>
                    <style>
                      body { font-family: sans-serif; padding: 20px; }
                      .chart-grid {
                        display: flex;
                        flex-wrap: wrap;
                        gap: 20px;
                      }
                      .chart-container {
                        flex: 1 1 calc(50% - 20px);
                        max-width: calc(50% - 20px);
                      }
                      canvas {
                        width: 100% !important;
                        height: 300px !important;
                      }
                      .section {
                        margin-bottom: 40px;
                      }
         .badge {
            background: #e74c3c;
            color: white;
            padding: 2px 8px;
            border-radius: 12px;
            cursor: pointer;
            font-size: 12px;
            margin-left: 6px;
          }
          .badge.missing { background: #f1c40f; }
          .badge.extra { background: #3498db; }
          .badge.wrong { background: #9b59b6; }
          .details { display: none; margin: 5px 0 10px 20px; }
                    </style>
                  </head>
                  <body>
                    <h1>Recitation Segment Analysis</h1>

                    <div class="section">
                      <h2>Detection Type Distribution</h2>
                      <div class="chart-grid">
                        <div class="chart-container">
                          <canvas id="detectionTypeChart"></canvas>
                        </div>
                      </div>
                    </div>

                    <div class="section">
                      <h2>Mistake Type Distribution</h2>
                      <div class="chart-grid">
                        <div class="chart-container">
                          <canvas id="mistakeTypeChart"></canvas>
                        </div>
                      </div>
                    </div>

                    <div class="section">
                      <h2>Top Words with Most Mistakes</h2>
                      <div class="chart-grid">
                        <div class="chart-container">
                          <canvas id="topMistakeWordsChart"></canvas>
                        </div>
                      </div>
                    </div>

                    <div class="section">
                      <h2>Mistake Ratio per Surah</h2>
                      <div class="chart-grid">
                        <div class="chart-container">
                          <canvas id="surahMistakeRatioChart"></canvas>
                        </div>
                      </div>
                    </div>
                    
                    <div class="section">
              <h2>Mistake Ratio per Reciter</h2>
              <div class="chart-grid">
                <div class="chart-container">
                  <canvas id="reciterMistakeRatioChart"></canvas>
                </div>
              </div>
            </div>

              <div class="section">
        <h2>Top Expected vs Received Mistakes</h2>
       
        <% top_expected.each_with_index do |(expected, variations), i| %>
          <div>
            <strong><%= i + 1 %>. "<%= expected %>"</strong>
            <ul>
              <% variations.group_by { |_, v| v[:type] }.each_with_index do |(type, items), j| %>
                <% total_count = items.sum { |_, v| v[:count] } %>
                <% css_class = ["missing", "extra", "wrong"].include?(type) ? type : "unknown" %>
                <li>
                  <%= type.capitalize %>
                  <span class="badge <%= css_class %> mistake-counter"><%= total_count %></span>
                  <div class="details">
                    <ul>
                      <% items.sort_by { |_, v| -v[:count] }.each do |received, v| %>
                        <li>Received as: "<%= received %>" (<%= v[:count] %> times)</li>
                      <% end %>
                    </ul>
                  </div>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>
                    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
                    <script>
                      const detectionTypeData = <%= detection_chart_data.to_json.html_safe %>;
                      const mistakeTypeData = <%= mistake_type_chart_data.to_json.html_safe %>;
                      const topMistakeWordsData = <%= top_mistake_words_data.to_json.html_safe %>;
                      const surahMistakeRatioData = <%= surah_mistake_ratio_data.to_json.html_safe %>;
                      const reciterMistakeRatioData = <%= reciter_mistake_ratio_data.to_json.html_safe %>;

                      document.querySelectorAll('.mistake-counter').forEach((el) => {
                        el.addEventListener('click', (event) => {
                          const details = el.nextElementSibling;
                          if (details) {
                            details.style.display = details.style.display === 'block' ? 'none' : 'block';
                          }
                        })
                      })
       
                      new Chart(document.getElementById('detectionTypeChart'), {
                        type: 'bar',
                        data: {
                          labels: detectionTypeData.labels,
                          datasets: [{
                            label: 'Count',
                            data: detectionTypeData.values,
                            backgroundColor: 'rgba(75, 192, 192, 0.6)'
                          }]
                        }
                      });

                      new Chart(document.getElementById('mistakeTypeChart'), {
                        type: 'bar',
                        data: {
                          labels: mistakeTypeData.labels,
                          datasets: [{
                            label: 'Count',
                            data: mistakeTypeData.values,
                            backgroundColor: 'rgba(255, 99, 132, 0.6)'
                          }]
                        }
                      });

                      new Chart(document.getElementById('topMistakeWordsChart'), {
                        type: 'bar',
                        data: {
                          labels: topMistakeWordsData.labels,
                          datasets: [{
                            label: 'Mistake Count',
                            data: topMistakeWordsData.values,
                            backgroundColor: 'rgba(153, 102, 255, 0.6)'
                          }]
                        }
                      });

                      new Chart(document.getElementById('surahMistakeRatioChart'), {
                        type: 'bar',
                        data: {
                          labels: surahMistakeRatioData.labels,
                          datasets: [{
                            label: 'Mistake Ratio (%)',
                            data: surahMistakeRatioData.values,
                            backgroundColor: 'rgba(255, 206, 86, 0.6)'
                          }]
                        }
                      });
                      

            new Chart(document.getElementById('reciterMistakeRatioChart'), {
              type: 'bar',
              data: {
                labels: reciterMistakeRatioData.labels,
                datasets: [{
                  label: 'Mistake Ratio (%)',
                  data: reciterMistakeRatioData.values,
                  backgroundColor: 'rgba(54, 162, 235, 0.6)'
                }]
              }
            });
                    </script>
                  </body>
                  </html>
    HTML

    result = ERB.new(template, trim_mode: '-').result(binding)
    File.write(output_file, result)
    puts "✅ Report generated at: #{output_file}"
  end

  task cleanup_audio: :environment do
    recitations = Audio::Recitation.all
    recitations.each do |recitation|
      base_path = "tmp/audio/#{recitation.id}"
      FileUtils.rm_rf("#{base_path}/surah/mp3")

      puts "Cleaned up audio files for Reciter #{recitation.id}"
    end
  end
end