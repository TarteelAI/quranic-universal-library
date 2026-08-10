def build_transcript_issues_html(rows)
  require "json"

  data_json = rows.to_json

  <<~HTML
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Transcript fixes review</title>
      <style>
        :root { color-scheme: light dark; --head-h: 150px; }
        * { box-sizing: border-box; }
        body { font-family: -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; margin: 0; background: #0f1115; color: #e7e9ee; }
        #topbar { position: sticky; top: 0; background: #151923; border-bottom: 1px solid #262c3a; z-index: 10; }
        .topbar-inner { padding: 14px 20px 0; }
        h1 { font-size: 18px; margin: 0 0 4px; }
        .summary { color: #9aa3b2; font-size: 13px; }
        .controls { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 12px; }
        .controls input, .controls select { background: #0f1115; color: #e7e9ee; border: 1px solid #333b4d; border-radius: 8px; padding: 8px 10px; font-size: 13px; }
        .controls input { min-width: 240px; flex: 1; }
        .tabs { display: flex; gap: 6px; overflow-x: auto; padding: 12px 20px 12px; scrollbar-width: thin; }
        .tab { flex: 0 0 auto; background: #0f1115; color: #c6ccd8; border: 1px solid #2a3242; border-radius: 999px; padding: 6px 12px; font-size: 13px; cursor: pointer; white-space: nowrap; display: inline-flex; align-items: center; gap: 6px; }
        .tab:hover { border-color: #3d4a63; }
        .tab.active { background: #1d59c9; border-color: #1d59c9; color: #fff; }
        .tab .tcount { font-size: 11px; background: rgba(255,255,255,.15); border-radius: 999px; padding: 1px 7px; }
        .tab.active .tcount { background: rgba(255,255,255,.25); }
        main { padding: 8px 20px 60px; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #222836; vertical-align: top; }
        thead th { color: #9aa3b2; font-weight: 600; position: sticky; top: var(--head-h); background: #10141c; z-index: 4; }
        tr:hover td { background: #161b26; }
        a.key { color: #7bb0ff; text-decoration: none; font-weight: 600; }
        a.key:hover { text-decoration: underline; }
        .pos { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; color: #b6c0d4; font-size: 12px; word-break: break-word; }
        .added { color: #6fd08c; font-weight: 600; }
        .removed { color: #f08a8a; font-weight: 600; }
        .empty { color: #9aa3b2; padding: 40px 0; text-align: center; }
      </style>
    </head>
    <body>
      <div id="topbar">
        <div class="topbar-inner">
          <h1>Transcript fixes review</h1>
          <div class="summary" id="summary"></div>
          <div class="controls">
            <input id="search" type="search" placeholder="Search ayah key (e.g. 33:50) in this reciter…">
            <select id="sort">
              <option value="key">Sort: ayah key ↑</option>
              <option value="added">Sort: most words added ↓</option>
            </select>
          </div>
        </div>
        <div class="tabs" id="tabs"></div>
      </div>
      <main id="content"></main>
      <script>
        const DATA = #{data_json};

        const GROUPS = {};
        DATA.forEach(r => { (GROUPS[r.reciter] = GROUPS[r.reciter] || []).push(r); });
        const RECITERS = Object.keys(GROUPS).sort((a, b) => a.localeCompare(b));
        let active = RECITERS[0] || null;

        const searchEl = document.getElementById("search");
        const sortEl = document.getElementById("sort");

        const keyParts = (k) => (k || "").split(":").map(Number);
        const cmpKey = (a, b) => {
          const ap = keyParts(a.verse_key), bp = keyParts(b.verse_key);
          return (ap[0] - bp[0]) || (ap[1] - bp[1]);
        };

        function matches(r, q) {
          if (!q) return true;
          return String(r.verse_key).toLowerCase().includes(q);
        }

        function buildTabs(q) {
          const bar = document.getElementById("tabs");
          bar.innerHTML = "";
          RECITERS.forEach(name => {
            const n = GROUPS[name].filter(r => matches(r, q)).length;
            if (q && n === 0) return;
            const b = document.createElement("button");
            b.className = "tab" + (name === active ? " active" : "");
            b.innerHTML = escapeHtml(name || "(unnamed)") + '<span class="tcount">' + n + '</span>';
            b.onclick = () => { active = name; render(); };
            bar.appendChild(b);
          });
        }

        function render() {
          const q = searchEl.value.trim().toLowerCase();

          const visible = RECITERS.filter(name => !q || GROUPS[name].some(r => matches(r, q)));
          if (!visible.includes(active)) active = visible[0] || null;

          buildTabs(q);

          const content = document.getElementById("content");
          content.innerHTML = "";

          document.getElementById("summary").textContent =
            DATA.length + " fixed ayah(s) across " + RECITERS.length + " reciter(s)";

          if (!active) {
            content.innerHTML = '<div class="empty">No matching fixed ayahs.</div>';
            requestAnimationFrame(setStick);
            return;
          }

          let list = GROUPS[active].filter(r => matches(r, q));
          if (sortEl.value === "added") list.sort((a, b) => (b.added - a.added) || cmpKey(a, b));
          else list.sort(cmpKey);

          const table = document.createElement("table");
          table.innerHTML =
            '<thead><tr><th>Ayah</th><th>Words</th><th>Original positions</th><th>Corrected positions</th></tr></thead>';
          const tbody = document.createElement("tbody");

          list.forEach(r => {
            const tr = document.createElement("tr");
            const diff = r.added > 0 ? '<span class="added">+' + r.added + '</span>'
                       : (r.added < 0 ? '<span class="removed">' + r.added + '</span>' : '');
            tr.innerHTML =
              '<td><a class="key" href="' + r.url + '" target="_blank" rel="noopener">' + escapeHtml(r.verse_key) + '</a></td>' +
              '<td>' + r.original_count + ' → ' + r.corrected_count + ' ' + diff + '</td>' +
              '<td class="pos">' + r.original.join(", ") + '</td>' +
              '<td class="pos">' + r.corrected.join(", ") + '</td>';
            tbody.appendChild(tr);
          });

          table.appendChild(tbody);
          content.appendChild(table);
          requestAnimationFrame(setStick);
        }

        function setStick() {
          const h = document.getElementById("topbar").offsetHeight;
          document.documentElement.style.setProperty("--head-h", h + "px");
        }

        function escapeHtml(s) {
          return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
        }

        searchEl.addEventListener("input", render);
        sortEl.addEventListener("change", render);
        window.addEventListener("resize", setStick);
        render();
      </script>
    </body>
    </html>
  HTML
end

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

      invalid_segments = []
      1.upto(114) do |chapter_id|
        segments = recitation
                     .audio_segments
                     .where(chapter_id: chapter_id)
                     .order('verse_id ASC')

        segments.each_with_index do |seg, i|
          nxt = segments[i + 1]
          next if nxt.nil?

          gap = seg.timestamp_to - nxt.timestamp_from
          next if [0, 1, -1].include?(gap)

          invalid_segments << [
            seg.verse_key,
            seg.timestamp_from,
            seg.timestamp_to,
            nxt.verse_key,
            nxt.timestamp_from,
            gap
          ]
        end
      end

      if invalid_segments.present?
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
          invalid_segments.each do |row|
            csv < row
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

      invalid_segments = []
      segments.each do |surah, surah_segments|
        sorted = surah_segments.sort_by { |s| s["ayah"] }
        sorted.each_with_index do |seg, i|
          nxt = sorted[i + 1]
          next if nxt.nil?

          gap = seg["end"] - nxt["start"]
          next if [0, 1, -1].include?(gap)

          invalid_segments << [
            surah,
            seg["ayah"],
            seg["start"],
            seg["end"],
            nxt["start"],
            gap
          ]
        end
      end

      if invalid_segments.present?
        CSV.open(output_path, "w") do |csv|
          csv << [
            "surah",
            "ayah",
            "start",
            "end",
            "next_start",
            "gap"
          ]
        end

        invalid_segments.each do |row|
          csv < row
        end
      else
        puts "Segments for recitation #{id} looks good!"
      end
    end

    output_path = "public/segment_gaps/manifest"
    archive_path = "#{output_path}.tar.bz2"
    system('tar', '-cjf', archive_path, '-C', File.dirname(output_path), File.basename(output_path))

    puts "CSV exported to #{archive_path}"
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


  desc "Export transcripts as a single JSON file for a given recitation and chapter"
  task :export_transcripts_json, [:recitation_id, :chapter_id, :script] => :environment do |_t, args|
    require "json"

    recitation_id = args[:recitation_id].to_i
    chapter_id = args[:chapter_id].to_i
    script = (args[:script].presence || "text_imlaei").to_sym

    if recitation_id.zero? || chapter_id.zero?
      puts "Usage: rake audio_segments:export_transcripts_json[RECITATION_ID,CHAPTER_ID,SCRIPT]"
      exit 1
    end

    segments = Audio::Segment
                 .where(audio_recitation_id: recitation_id, chapter_id: chapter_id)
                 .includes(:verse)
                 .order("verse_id ASC")

    puts "Exporting transcripts for #{segments.count} Audio::Segment records..."

    data = segments.each_with_object({}) do |segment, hash|
      hash[segment.verse_key] = {
        "transcript" => segment.corrected_transcript(script: script, as_array: true),
      }
    end

    FileUtils.mkdir_p("tmp/segment_transcripts")
    output_path = Rails.root.join("tmp", "segment_transcripts", "#{recitation_id}_#{chapter_id}.json")
    File.write(output_path, JSON.pretty_generate(data))

    puts "✅ Done! Transcripts written to #{output_path}"
  end

  desc "Bulk export corrected transcripts (transcript/<recitation_id>/<chapter_id>.json) + a review HTML of fixed ayahs"
  task :export_corrected_transcripts, [:script] => :environment do |_t, args|

    def corrected_word_positions(segment)
      positions = segment.get_segments.map { |s| s[0] }
      Audio::SegmentReconstruct.reconstruct_word_positions(positions, segment.verse&.words_count)
    end

    def corrected_transcript(segment, script: :text_imlaei, as_array: false)
      return as_array ? [] : '' if segment.get_segments.blank?

      words_by_position = segment.verse.words.order(:position).pluck(:position, script).to_h
      words = corrected_word_positions(segment).map { |p| words_by_position[p] }.compact_blank

      as_array ? words : words.join(' ')
    end

    require "json"

    script = (args[:script].presence || "text_imlaei").to_sym


    recitation_ids = [1,2,3,4,6,7,9,10,12,13,65,161,164,174,175,179]

    base_url = "http://qul.tarteel.ai"
    output_root = Rails.root.join("tmp", "segment_transcripts", "transcript")
    FileUtils.mkdir_p(output_root)

    scope = Audio::Recitation.order(:id)
    scope = scope.where(id: recitation_ids) if recitation_ids.present?

    fixed_rows = []
    total_recitations = 0
    total_chapters = 0

    scope.find_each do |recitation|
      chapter_ids = Audio::Segment
                      .where(audio_recitation_id: recitation.id)
                      .distinct
                      .pluck(:chapter_id)
                      .compact
                      .sort

      next if chapter_ids.empty?

      total_recitations += 1
      reciter_dir = output_root.join(recitation.id.to_s)
      FileUtils.mkdir_p(reciter_dir)

      chapter_ids.each do |chapter_id|
        total_chapters += 1

        segments = Audio::Segment
                     .where(audio_recitation_id: recitation.id, chapter_id: chapter_id)
                     .includes(verse: :words)
                     .order("verse_id ASC")

        data = {}

        segments.each do |segment|
          next if segment.verse.blank?

          original = segment.get_segments.map { |s| s[0].to_i }.reject(&:zero?)
          corrected = corrected_word_positions(segment)

          data[segment.verse_key] = {
            "transcript" => corrected_transcript(segment, script: script, as_array: true)
          }

          next if corrected == original

          fixed_rows << {
            "recitation_id" => recitation.id,
            "reciter" => recitation.name.to_s,
            "chapter_id" => chapter_id,
            "verse_number" => segment.verse_number,
            "verse_key" => segment.verse_key,
            "original" => original,
            "corrected" => corrected,
            "original_count" => original.size,
            "corrected_count" => corrected.size,
            "added" => corrected.size - original.size,
            "url" => "#{base_url}/surah_audio_files/#{chapter_id}/segment_builder?recitation_id=#{recitation.id}&verse=#{segment.verse_number}"
          }
        end

        File.write(reciter_dir.join("#{chapter_id}.json"), JSON.pretty_generate(data))
      end

      puts "  reciter #{recitation.id} (#{recitation.name}) → #{chapter_ids.size} chapters"
    end

    html_path = output_root.join("index.html")
    File.write(html_path, build_transcript_issues_html(fixed_rows))

    puts "✅ Done!"
    puts "   Recitations: #{total_recitations}, chapters: #{total_chapters}, fixed ayahs: #{fixed_rows.size}"
    puts "   JSON:   #{output_root}/<recitation_id>/<chapter_id>.json"
    puts "   Review: #{html_path}"
  end

  desc "Fill missing word segments (first/middle/last) for reciters+chapters present in DATA_DIR, writing to DB + a CSV report"
  task :fix_missing_word_segments, [:data_dir, :script] => :environment do |_t, args|
    require "csv"

    data_dir = args[:data_dir].presence || "/Volumes/dev/data/transcript"
    script = (args[:script].presence || "text_imlaei").to_sym

    unless Dir.exist?(data_dir)
      puts "Data dir not found: #{data_dir}"
      exit 1
    end

    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    FileUtils.mkdir_p("tmp/segment_fixes")
    out_path = Rails.root.join("tmp", "segment_fixes", "fix_missing_words_#{timestamp}.csv")

    fixed_ayahs = 0
    fixed_words = 0
    skipped_no_timing = 0
    scanned = 0

    CSV.open(out_path, "w") do |csv|
      csv << %w[recitation_id chapter_id verse_key fixed_words types before after]

      Dir.children(data_dir).select { |d| d.to_i.positive? }.sort_by(&:to_i).each do |rid_dir|
        recitation_id = rid_dir.to_i

        chapter_ids = Dir.children(File.join(data_dir, rid_dir))
                         .select { |f| f.end_with?(".json") }
                         .map { |f| File.basename(f, ".json").to_i }
                         .select(&:positive?)
                         .sort

        chapter_ids.each do |chapter_id|
          segments = Audio::Segment
                       .where(audio_recitation_id: recitation_id, chapter_id: chapter_id)
                       .includes(verse: :words)
                       .order("verse_id ASC")

          segments.each do |segment|
            verse = segment.verse
            next if verse.blank? || segment.segments.blank?

            scanned += 1

            words_count = verse.words_count.to_i
            next if words_count.zero?

            present = segment.get_segments.map { |s| s[0].to_i }
            missing = (1..words_count).to_a - present
            next if missing.empty?

            if segment.timestamp_from.blank? || segment.timestamp_to.blank?
              skipped_no_timing += 1
              next
            end

            word_texts = verse.words.order(:position).each_with_object({}) do |w, h|
              h[w.position] = w.send(script).to_s if w.position.between?(1, words_count)
            end

            before = segment.segments

            result = Audio::SegmentMissingWordFiller.fill(
              segments: segment.get_segments,
              word_texts: word_texts,
              words_count: words_count,
              ayah_from: segment.timestamp_from,
              ayah_to: segment.timestamp_to
            )

            next if result[:fixes].empty?

            segment.set_segments!(result[:segments])

            fixed_ayahs += 1
            fixed_words += result[:fixes].size

            csv << [
              recitation_id,
              chapter_id,
              segment.verse_key,
              result[:fixes].map { |f| f[:word] }.join(","),
              result[:fixes].map { |f| f[:type] }.uniq.join(","),
              before.to_json,
              result[:segments].to_json
            ]
          end
        end

        puts "  reciter #{recitation_id}: #{fixed_ayahs} ayahs fixed so far"
      end
    end

    puts "✅ Done!"
    puts "   Scanned ayahs: #{scanned}"
    puts "   Fixed ayahs: #{fixed_ayahs} (#{fixed_words} words filled)"
    puts "   Skipped (no ayah timing): #{skipped_no_timing}"
    puts "   Report: #{out_path}"
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
