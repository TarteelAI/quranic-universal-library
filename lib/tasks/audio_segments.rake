namespace :audio_segments do
  task validate_segment_gaps: :environment do
    tag = Tag.find(4)
    resources = ResourceContent
                  .recitations
                  .one_chapter
                  .joins(:resource_tags)
                  .where(resource_tags: { tag_id: tag.id })

    FileUtils.mkdir_p("public/segment_gaps/reciter")

    recitations = Audio::Recitation.where(resource_content_id: resources.pluck(:id))
    recitations.each do |recitation|
      puts "Reciter #{recitation.id} - #{recitation.name}:"

      output_path = Rails.root.join("public", "segment_gaps", "reciter", "#{recitation.get_resource_content.id}.csv")

      CSV.open(output_path, "w") do |csv|
        csv << [
          "ayah",
          "start",
          "end",
          "next ayah",
          "next start",
          "gap"
        ]

        1.upto(114) do |chapter_id|
          segments = recitation
                       .audio_segments
                       .where(chapter_id: chapter_id)
                       .order('verse_id ASC')

          segments.each_with_index do |seg, i|
            nxt = segments[i + 1]
            next if nxt.nil?

            gap = seg.timestamp_to - nxt.timestamp_from
            next if gap == 0

            csv << [
              seg.verse_key,
              seg.timestamp_from,
              seg.timestamp_to,
              nxt.verse_key,
              nxt.timestamp_from,
              gap
            ]
          end
        end
      end
    end

    file_path = "public/segment_gaps/reciter"
    archive_path = "#{file_path}.tar.bz2"
    system('tar', '-cjf', archive_path, '-C', File.dirname(file_path), File.basename(file_path))

    puts "CSV exported to #{archive_path}"
  end

  task validate_segment_manifest: :environment do
    require "open-uri"
    require "json"
    require "csv"

    manifest_url = "TODO"
    manifest = Oj.load URI.open(manifest_url).read

    manifest['assets']['segments'].each do |data|
      id = data['id']
      url = "#{data['url']}?v=#{data['version']}"

      puts "Downloading segments for reciter #{id}..."
      json = URI.open(url).read
      segments = JSON.parse(json)

      FileUtils.mkdir_p("public/segment_gaps/manifest")
      output_path = Rails.root.join("public", "segment_gaps", "manifest", "#{id}.csv")

      CSV.open(output_path, "w") do |csv|
        csv << [
          "surah",
          "ayah",
          "start",
          "end",
          "next_start",
          "gap"
        ]

        segments.each do |surah, surah_segments|
          sorted = surah_segments.sort_by { |s| s["ayah"] }
          sorted.each_with_index do |seg, i|
            nxt = sorted[i + 1]
            next if nxt.nil?

            gap = seg["end"] - nxt["start"]
            next unless gap > 0

            csv << [
              surah,
              seg["ayah"],
              seg["start"],
              seg["end"],
              nxt["start"],
              gap
            ]
          end
        end
      end

      puts "CSV exported to #{output_path}"
    end
  end

  desc "Find Audio::Segment records with missing, misplaced, or invalid timing issues"
  task validate_segments: :environment do
    require "csv"

    recitation_id = 65
    chapter_id = ''

    segments = Audio::Segment
                 .where(audio_recitation_id: recitation_id)
                 .includes(:verse)
                 .order('verse_id ASC')
    segments = segments.where(chapter_id: chapter_id) if chapter_id.present?

    FileUtils.mkdir_p("tmp/segments_issues")
    output_path = Rails.root.join("tmp", 'segments_issues', "#{recitation_id}.csv")
    puts "Scanning #{segments.count} Audio::Segment records..."

    CSV.open(output_path, "w") do |csv|
      csv << ["id", "verse_key", "issue_type", "description", "details"]

      segments.find_each do |segment|
        begin
          issues = []
          ayah_segments = segment.get_segments
          next if ayah_segments.empty?

          verse = segment.verse
          max_word = verse.words_count

          invalid_timing = ayah_segments.select { |s| s[1].to_f > s[2].to_f }
          if invalid_timing.present?
            issues << {
              type: "invalid_timing",
              desc: "Start time is greater than end time",
              details: invalid_timing.map { |s| "word #{s[0]} (#{s[1]} > #{s[2]})" }.join("; ")
            }
          end

          word_positions = ayah_segments.map { |s| s[0] }
          missing = (1..max_word).to_a - word_positions
          if missing.present?
            issues << {
              type: "missing_words",
              desc: "Some words are missing from segments",
              details: "Missing positions: #{missing.join(', ')}"
            }
          end

          # Check for misplaced words (sequence anomaly)
          misplaced = []
          last_word = 0
          ayah_segments.each_with_index do |s, i|
            word_num = s[0].to_i
            if word_num < last_word
              misplaced << "word #{word_num} appears after word #{last_word} at index #{i}"
            end
            last_word = word_num
          end

          if misplaced.present?
            issues << {
              type: "misplaced_words",
              desc: "Word order anomaly detected",
              details: misplaced.join("; ")
            }
          end

          next if issues.empty?

          issues.each do |issue|
            csv << [
              segment.id,
              segment.verse_key,
              issue[:type],
              issue[:desc],
              issue[:details]
            ]
          end

        rescue => e
          csv << [segment.id, segment.verse_key, "error", e.message, ""]
        end
      end
    end

    puts "✅ Done! Results saved to #{output_path}"
  end

  desc "Auto-fix issues in Audio::Segment records"
  task fix_issues: :environment do
    require "csv"

    recitation_id = 65
    chapter_id = ''

    scope = Audio::Segment.where(audio_recitation_id: recitation_id)
    scope = scope.where(chapter_id: chapter_id) if chapter_id.present?

    FileUtils.mkdir_p("tmp/segments_issues")
    output_path = Rails.root.join("tmp", 'segments_issues', "#{recitation_id}_fixes.csv")
    puts "🔧 Fixing #{scope.count} Audio::Segment records..."

    LETTER_SCORES = {
      'ٓ' => 6,
      '' => 4,
      'آّ' => 6,
      'ٰ' => 4
    }

    def calculate_word_text_score(text)
      base_score = normalize_text(text).length
      diacritic_score = text.chars.sum { |char| LETTER_SCORES[char] || 0 }
      base_score + diacritic_score
    end

    def divide_segment_time(start_time, end_time, texts)
      return [[start_time, end_time]] if texts.blank? || texts.size == 1

      total_duration = end_time - start_time
      scores = texts.map { |t| calculate_word_text_score(t) }
      total_score = scores.sum
      return [[start_time, end_time]] if total_score.zero?

      result = []
      current_start = start_time

      scores.each_with_index do |score, i|
        segment_duration = (score.to_f / total_score * total_duration).round
        segment_end = (i == scores.size - 1) ? end_time : current_start + segment_duration
        result << [current_start, segment_end]
        current_start = segment_end
      end

      result
    end

    def normalize_text(text)
      text.to_s.gsub(/[^\p{Arabic}]/, '')
    end

    CSV.open(output_path, "w") do |csv|
      csv << ["id", "verse_key", "fixes_applied", "status", "before", "after"]

      scope.find_each do |segment|
        begin
          fixes_applied = []
          ayah_segments = segment.segments || []
          next if ayah_segments.empty?
          before_json = ayah_segments.deep_dup

          verse = segment.verse
          words = verse.words.order(:position)
          max_word = verse.words_count

          word_positions = ayah_segments.map { |s| s[0] }

          # 1️⃣ Fix invalid timing (start > end)
          ayah_segments.each do |s|
            if s[1].to_f > s[2].to_f
              s[1], s[2] = s[2], s[1]
              fixes_applied << "swapped_start_end(word #{s[0]})"
            end
          end

          # 2️⃣ Fix misplaced words
          last_word = -Float::INFINITY
          misplaced = []
          ayah_segments.each_with_index do |s, i|
            if s[0] < last_word
              misplaced << i
            end
            last_word = s[0]
          end
          unless misplaced.empty?
            misplaced.reverse_each { |i| ayah_segments.delete_at(i) }
            fixes_applied << "removed_misplaced_words"
          end

          # 3️⃣ Fix missing words (skip if consecutive missing)
          missing = (1..max_word).to_a - ayah_segments.map { |s| s[0] }
          missing.each do |missing_word|
            prev_index = ayah_segments.rindex { |s| s[0] < missing_word }
            next_index = ayah_segments.index { |s| s[0] > missing_word }
            next unless prev_index && next_index

            # Skip if consecutive missing
            next if missing.include?(missing_word - 1) || missing.include?(missing_word + 1)

            prev = ayah_segments[prev_index]
            prev_word = words.find_by(position: prev[0])&.text_imlaei.to_s
            missing_text = words.find_by(position: missing_word)&.text_imlaei.to_s
            next if prev_word.blank? || missing_text.blank?

            parts = divide_segment_time(prev[1], prev[2], [prev_word, missing_text])
            if parts.size == 2
              prev[1], prev[2] = parts[0]
              new_start, new_end = parts[1]
              ayah_segments.insert(prev_index + 1, [missing_word, new_start, new_end])
              fixes_applied << "inserted_missing_word(#{missing_word})"
            end
          end

          # 4️⃣ Ensure next start >= previous end
          ayah_segments.each_with_index do |s, i|
            next if i.zero?
            prev = ayah_segments[i - 1]
            if s[1] < prev[2]
              s[1] = prev[2]
              fixes_applied << "adjusted_overlap(word #{s[0]})"
            end
          end

          # 5️⃣ Ensure last word end time <= segment.timestamp_to
          if segment.timestamp_to.present? && ayah_segments.last[2] < segment.timestamp_to
            ayah_segments.last[2] = segment.timestamp_to
            fixes_applied << "corrected_last_word_end"
          end

          # Skip saving if no changes
          next if fixes_applied.empty?

          segment.update(
            segments: ayah_segments,
            segments_count: ayah_segments.size
          )

          csv << [
            segment.id,
            segment.verse_key,
            fixes_applied.join("; "),
            "fixed",
            before_json.to_json,
            ayah_segments.to_json
          ]

          puts "✅ Fixed #{segment.verse_key}: #{fixes_applied.join(', ')}"
        rescue => e
          csv << [segment.id, segment.verse_key, "", "error: #{e.message}", "", ""]
        end
      end
    end

    puts "✅ Done! Fixed segments written to #{output_path}"
  end

  # Ignore this
  desc 'Fix missing word segments for given recitation and chapter'
  task :fix_missing_words => :environment do
    LETTER_SCORES = {
      'ٓ' => 6,
      '' => 4,
      'آّ' => 6,
      'ٰ' => 4
    }

    def calculate_word_text_score(text)
      base_score = normalize_text(text).length
      diacritic_score = text.chars.sum { |char| LETTER_SCORES[char] || 0 }
      base_score + diacritic_score
    end

    def divide_segment_time(start_time, end_time, texts)
      return [[start_time, end_time]] if texts.blank? || texts.size == 1

      total_duration = end_time - start_time
      scores = texts.map { |t| calculate_word_text_score(t) }
      total_score = scores.sum
      return [[start_time, end_time]] if total_score.zero?

      result = []
      current_start = start_time

      scores.each_with_index do |score, i|
        segment_duration = (score.to_f / total_score * total_duration).round
        segment_end = (i == scores.size - 1) ? end_time : current_start + segment_duration
        result << [current_start, segment_end]
        current_start = segment_end
      end

      result
    end

    def normalize_text(text)
      text.to_s.gsub(/[^\p{Arabic}]/, '')
    end

    recitation_id = ''
    chapter_id = ''

    unless recitation_id && chapter_id && recitation_id > 0 && chapter_id > 0
      puts 'Usage: rake audio_segments:fix_missing_words[RECITATION_ID,CHAPTER_ID]'
      exit 1
    end

    timestamp = Time.now.strftime('%Y%m%d%H%M%S')
    out_path = Rails.root.join('tmp', "audio_segments_fixed_missing_#{recitation_id}_#{chapter_id}_#{timestamp}.csv")

    CSV.open(out_path, 'w') do |csv|
      csv << %w[id verse_key missing_words fixed description before after]

      Audio::Segment.where(audio_recitation_id: recitation_id, chapter_id: chapter_id).find_each do |segment|
        begin
          verse = segment.verse
          next unless verse

          words = verse.words.order(:position)
          max_word = words.count

          ayah_segments = segment.segments || []
          word_positions = ayah_segments.map { |s| s[0] }
          missing = (1..max_word).to_a - word_positions
          next if missing.empty?

          before_json = ayah_segments.deep_dup
          fixes_applied = []

          missing.each do |missing_word|
            # Find previous and next known word segments
            prev_index = ayah_segments.rindex { |s| s[0] < missing_word }
            next_index = ayah_segments.index { |s| s[0] > missing_word }

            next unless prev_index && next_index

            prev = ayah_segments[prev_index]
            nxt = ayah_segments[next_index]

            # Skip if consecutive missing words exist
            next unless missing.exclude?(missing_word + 1) && missing.exclude?(missing_word - 1)

            prev_word = words.find_by(position: prev[0])&.text_imlaei.to_s
            missing_text = words.find_by(position: missing_word)&.text_imlaei.to_s
            next if prev_word.blank? || missing_text.blank?

            # Divide previous segment’s time into two
            parts = divide_segment_time(prev[1], prev[2], [prev_word, missing_text])

            if parts.size == 2
              prev[1], prev[2] = parts[0]
              new_start, new_end = parts[1]

              # Insert missing word segment right after previous
              ayah_segments.insert(prev_index + 1, [missing_word, new_start, new_end])
              fixes_applied << missing_word
            end
          end

          next if fixes_applied.empty?

          # Save back (order preserved)
          segment.update!(segments: ayah_segments)

          csv << [
            segment.id,
            segment.verse_key,
            fixes_applied.join(','),
            'yes',
            'missing words fixed',
            before_json.to_json,
            ayah_segments.to_json
          ]

        rescue => e
          csv << [segment.id, segment.verse_key, '', 'no', "error: #{e.message}", '', '']
        end
      end
    end

    puts "Fix complete. Report saved to #{out_path}"
  end
end
