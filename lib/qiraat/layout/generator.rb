# frozen_string_literal: true

require 'json'
require 'csv'
require_relative '../import/edition_words'
require_relative '../import/script_text'

module Qiraat
  module Layout
    # Builds the 15-line page layout of one KFGQPC edition from its quran-text
    # mushaf file (P5.3): the Mushaf row, its mushaf_words (one row per printed
    # word plus an ayah-end marker after each counted ayah), the surah-header
    # and basmalah lines in mushaf_line_alignments, and the page stats.
    #
    # Lines. quran-text's `line_starts` marks the positions that begin a
    # printed text line; a surah header and the basmalah occupy lines of their
    # own that carry no words, so the physical line number is the text line
    # index plus the header/basmalah lines inserted before it on that page. The
    # Complex's own CSV (page, line_start, line_end per ayah) is the publisher's
    # fact: every ayah is checked against it and disagreements are written to
    # tmp/qiraat/layout-review-<key>.json for review.
    #
    # Words. Each printed position maps to the shared number(s) it reads and
    # through them to the QUL words row (see EditionWords); verse_id is the
    # Kufi verse of that row, ayah_id the numbered ayah of the mushaf's
    # numbering. A marker's word_id is the Hafs end-marker row when the ayah
    # ends where the Kufi verse ends, nil otherwise (P5.2 made word_id nullable
    # for exactly this).
    #
    # Idempotent: re-running for the same edition deletes and rebuilds that
    # mushaf's words, pages and alignments only. Nothing else is touched.
    class Generator
      include Qiraat::Import::EditionWords

      BATCH = 5000
      CENTERED_PAGES = [1, 2].freeze # the Complex sets the first two pages centred, as mushaf 5 records
      LINES_PER_PAGE = 15

      # The Complex's per-ayah page/line files, relative to the kfgqpc-resources mirror
      CSV_FILES = {
        'hafs' => 'quran-dev/uthmanic-hafs/UthmanicHafs_v2-0 data/hafsData_v2-0.csv',
        'shubah' => 'quran-dev/uthmanic-shuba/UthmanicShuba_v2-0 data/shubaData_v2-0.csv',
        'warsh' => 'quran-dev/uthmanic-warsh/UthmanicWarsh_v2-1 data/warshData_v2-1.csv',
        'qalun' => 'quran-dev/uthmanic-qaloun/UthmanicQaloun_v2-1 data/QalounData_v2-1.csv',
        'duri' => 'quran-dev/uthmanic-douri/UthmanicDouri_v2-0 data/DouriData_v2-0.csv',
        'susi' => 'quran-dev/uthmanic-sousi/UthmanicSousi_v2-0 data/SousiData_v2-0.csv'
        # bazzi: the Complex publishes no data CSV for the Bazzi edition
      }.freeze

      # pdf.quran.ws mirrors the Complex PDFs under this pattern; verified for warsh,
      # the others are checked page by page in P5.6
      def self.pdf_url(key)
        "https://pdf.quran.ws/pdfs/#{key}/quran-#{key}-mushaf.pdf"
      end

      attr_reader :key, :report, :mushaf, :rows, :alignments

      # key:        quran-text edition key (warsh, qalun, ...)
      # path:       data/mushaf/<key>.json
      # csv_path:   the Complex CSV for the cross-check (nil skips it)
      # compare_mushaf_id: an existing QUL mushaf to diff page/line per word against
      # pages_count: the mushaf's declared page count (defaults to the file's)
      def initialize(key:, path:, csv_path: nil, dry_run: false, logger: $stdout, compare_mushaf_id: nil, review_path: nil, pages_count: nil)
        @key = key
        @path = Pathname(path)
        @csv_path = csv_path && Pathname(csv_path)
        @dry_run = dry_run
        @logger = logger
        @compare_mushaf_id = compare_mushaf_id
        @review_path = review_path && Pathname(review_path)
        @pages_count = pages_count
        @report = { edition: key, dry_run: dry_run, warnings: [] }
      end

      def call
        data = JSON.parse(@path.read)
        slug, = Qiraat::Import::ScriptText::EDITIONS.fetch(key) { raise ArgumentError, "unknown quran-text edition #{key}" }
        # Hafs has no quran-text script row in QUL: its text is the qpc-hafs column, so the Hafs layout (a check against mushaf 5) uses that script
        @script = Script.find_by(slug: slug) || (key == 'hafs' ? Script.find_by!(slug: 'qpc-hafs') : raise(ActiveRecord::RecordNotFound, "script #{slug} missing: run qiraat:import:scripts"))
        @riwayah = @script.riwayah
        @numbering = @riwayah.default_numbering or raise ArgumentError, "riwayah #{@riwayah.slug} has no default numbering (run qiraat:import:numberings and printed_numberings)"
        @data = data
        load_lookups
        build
        cross_check_csv if @csv_path
        compare_with_mushaf if @compare_mushaf_id
        summarize
        write_review
        return report if @dry_run

        write
        report
      end

      private

      def log(msg)
        @logger&.puts(msg)
      end

      def warn(msg)
        report[:warnings] << msg
        log("  WARN #{msg}")
      end

      # ---------------------------------------------------------------- lookups

      def load_lookups
        @numbers_by_position = positions_to_numbers(@data)
        @marks = marks_by_position(@data)
        @words_by_number = words_by_number_map
        ids = @numbers_by_position.flatten.map { |n| @words_by_number[n] }.compact.uniq
        @word_info = {} # word id => [verse_id, position]
        Word.unscoped.where(id: ids).pluck(:id, :verse_id, :position).each { |id, v, p| @word_info[id] = [v, p] }
        @word_type = CharType.find_by!(name: 'word')
        @end_type = CharType.find_by!(name: 'end')
        @end_row_by_verse = Word.unscoped.where(char_type_id: @end_type.id).pluck(:verse_id, :id).to_h
        @ayahs = {} # "s:a" => {id:, number:, counted:, first_number:, last_number:}
        NumberedAyah.where(numbering_id: @numbering.id).pluck(:id, :ayah_key, :ayah_number, :counted, :first_number, :last_number).each do |id, k, n, c, f, l|
          @ayahs[k] = { id: id, number: n, counted: c, first_number: f, last_number: l }
        end
        @ayah_key_for_index = []
        @data['surahs'].each do |s|
          s['ayah_count'].times { |i| @ayah_key_for_index[s['first_ayah'] + i] = "#{s['number']}:#{i + 1}" }
        end
      end

      # ---------------------------------------------------------------- layout

      def build
        words = @data['words']
        page_starts = @data['page_starts']
        line_starts = @data['line_starts'].to_set
        ayah_starts = @data['ayah_starts']
        surah_at = @data['surah_starts'].each_with_index.to_h { |pos, i| [pos, @data['surahs'][i]] }
        has_basmalah_line = ->(s) { s['has_basmalah'] && s['number'] != 1 } # al-Fatihah's basmalah is its text

        @rows = []
        @alignments = [] # [page, line, kind, surah_number]
        @page_lines = Hash.new(0)
        @ayah_span = {} # ayah key => {first: [page, line], last: [page, line]}
        @stats = Hash.new(0)
        unmapped = []
        spanning = []
        duplicates = []

        page = 0
        line = 0
        pos_in_page = 0
        pos_in_line = 0
        ayah_i = -1
        current_ayah = nil
        current_key = nil # declared outside the loop: a variable first assigned inside the block would reset every position

        words.each_index do |pos|
          if page_starts[page] == pos
            page += 1
            line = 0
            pos_in_page = 0
            warn("page #{page} does not begin a text line (position #{pos})") unless line_starts.include?(pos)
          end
          if line_starts.include?(pos)
            line += 1
            pos_in_line = 0
            if (surah = surah_at[pos])
              @alignments << [page, line, :surah_name, surah['number']]
              line += 1
              if has_basmalah_line.call(surah)
                @alignments << [page, line, :bismillah, nil]
                line += 1
              end
            end
          elsif surah_at[pos]
            warn("surah #{surah_at[pos]['number']} starts mid-line at position #{pos}")
          end

          # the counted ayah this position belongs to; positions before a surah's first counted ayah are its "s:0" row
          if ayah_i + 1 < ayah_starts.size && ayah_starts[ayah_i + 1] == pos
            ayah_i += 1
            current_ayah = @ayahs[@ayah_key_for_index[ayah_i]] or raise "numbering #{@numbering.slug} has no ayah #{@ayah_key_for_index[ayah_i]}"
            current_key = @ayah_key_for_index[ayah_i]
          elsif current_ayah.nil?
            surah_number = @data['surahs'].count { |s| s['first_ayah'] <= ayah_i } # ayah_i == -1 => surah 1
            current_key = "#{[surah_number, 1].max}:0"
            uncounted = @ayahs[current_key] or raise "numbering #{@numbering.slug} has no uncounted row #{current_key}"
            current_ayah = uncounted.merge(uncounted_prefix: true)
          end

          nums = @numbers_by_position[pos]
          word_ids = nums.map { |n| @words_by_number[n] }.compact.uniq
          if word_ids.empty?
            unmapped << pos
            next
          end
          spanning << [pos, word_ids] if word_ids.size > 1
          word_id = word_ids.first
          duplicates << [pos, word_id] if @rows.last && @rows.last[:word_id] == word_id && @rows.last[:char_type_id] == @word_type.id
          verse_id, position = @word_info.fetch(word_id)
          pos_in_page += 1
          pos_in_line += 1
          @rows << {
            word_id: word_id, verse_id: verse_id, ayah_id: current_ayah[:id],
            char_type_id: @word_type.id, char_type_name: 'word',
            text: printed_form(@data, @marks, pos),
            page_number: page, line_number: line,
            position_in_page: pos_in_page, position_in_line: pos_in_line, position_in_verse: position
          }
          @stats[:words] += 1
          span = (@ayah_span[current_key] ||= { first: [page, line] })
          span[:last] = [page, line]
          @page_lines[page] = line

          # ayah-end marker after the last word of a counted ayah
          next unless current_ayah[:counted] && !current_ayah[:uncounted_prefix]

          last_of_ayah = (ayah_i + 1 < ayah_starts.size ? ayah_starts[ayah_i + 1] == pos + 1 : pos + 1 == words.size)
          next unless last_of_ayah

          kufi_end = kufi_end_after?(pos, verse_id, current_ayah)
          pos_in_page += 1
          pos_in_line += 1
          @rows << {
            word_id: kufi_end ? @end_row_by_verse[verse_id] : nil, verse_id: verse_id, ayah_id: current_ayah[:id],
            char_type_id: @end_type.id, char_type_name: 'end',
            text: current_ayah[:number].to_s.tr('0-9', '٠-٩'),
            page_number: page, line_number: line,
            position_in_page: pos_in_page, position_in_line: pos_in_line, position_in_verse: position + 1
          }
          @stats[:markers] += 1
          @stats[:markers_without_word] += 1 unless kufi_end
          current_ayah = nil
        end

        CENTERED_PAGES.each do |p|
          taken = @alignments.select { |a| a[0] == p }.map { |a| a[1] }
          (1..@page_lines[p]).each { |l| @alignments << [p, l, :center, nil] unless taken.include?(l) }
        end

        report[:pages] = page
        report[:unmapped_positions] = unmapped
        report[:spanning_positions] = spanning
        report[:duplicate_word_rows] = duplicates
        report[:lines_per_page] = @page_lines.values.tally.sort.to_h
        over = @page_lines.select { |_, n| n > LINES_PER_PAGE }.keys
        warn("pages with more than #{LINES_PER_PAGE} lines: #{over.inspect}") if over.any?
      end

      # The ayah ends where its Kufi verse ends when the next printed word is in
      # another verse (or the text ends). When the next word is not in the
      # database (a fixture slice) fall back to the numbering's own last number.
      def kufi_end_after?(pos, verse_id, ayah)
        nxt = pos + 1
        return true if nxt >= @data['words'].size

        next_id = @numbers_by_position[nxt].map { |n| @words_by_number[n] }.compact.first
        return @word_info[next_id][0] != verse_id if next_id

        @verse_last_number ||= Word.unscoped.where(hafs_reads: true, char_type_id: @word_type.id).group(:verse_id).maximum(Arel.sql('COALESCE(number_last, number)'))
        ayah[:last_number] == @verse_last_number[verse_id]
      end

      # ---------------------------------------------------------------- checks

      # Every ayah's page and lines against the Complex CSV. The CSV writes a
      # page-spanning ayah as "85-86" with line_end on the second page.
      #
      # The CSV may come from an earlier release than the text: the Sousi v2.0
      # CSV counts 6217 ayahs where the v3.0 text counts 6218 (67:9 نذير). In a
      # surah whose ayah count differs the keys no longer name the same ayahs,
      # so that surah is reported as skipped instead of compared.
      def cross_check_csv
        checked = 0
        agree = 0
        disagreements = []
        rows = CSV.read(@csv_path, headers: true, encoding: 'bom|utf-8')
        csv_counts = rows.group_by { |r| r['sura_no'].to_i }.transform_values(&:size)
        text_counts = @data['surahs'].to_h { |s| [s['number'], s['ayah_count']] }
        skipped = csv_counts.select { |s, n| text_counts[s] && text_counts[s] != n }.map { |s, n| { surah: s, csv_ayahs: n, text_ayahs: text_counts[s] } }
        skipped_surahs = skipped.map { |x| x[:surah] }.to_set
        rows.each do |r|
          next if skipped_surahs.include?(r['sura_no'].to_i)

          k = "#{r['sura_no']}:#{r['aya_no']}"
          span = @ayah_span[k] or next
          checked += 1
          pages = r['page'].split('-').map(&:to_i)
          expected = { page: pages.first, line_start: r['line_start'].to_i, end_page: pages.last, line_end: r['line_end'].to_i }
          actual = { page: span[:first][0], line_start: span[:first][1], end_page: span[:last][0], line_end: span[:last][1] }
          if expected == actual
            agree += 1
          else
            disagreements << { ayah: k, csv: expected, generated: actual }
          end
        end
        report[:csv] = { file: @csv_path.basename.to_s, checked: checked, agreeing: agree, disagreements: disagreements, skipped_surahs: skipped }
        log("  csv: #{agree}/#{checked} ayahs agree, #{disagreements.size} to review#{skipped.any? ? ", surahs skipped (ayah count differs from the CSV edition): #{skipped.map { |x| x[:surah] }.inspect}" : ''}")
      end

      # Page and line of every word against an existing QUL layout of the same words.
      def compare_with_mushaf
        existing = {}
        MushafWord.where(mushaf_id: @compare_mushaf_id).where.not(word_id: nil).pluck(:word_id, :page_number, :line_number).each { |w, p, l| existing[w] ||= [p, l] }
        page_diff = []
        line_diff = []
        missing = 0
        @rows.each do |row|
          next if row[:word_id].nil?

          e = existing[row[:word_id]]
          (missing += 1; next) if e.nil?
          if e[0] != row[:page_number]
            page_diff << [row[:word_id], e, [row[:page_number], row[:line_number]]]
          elsif e[1] != row[:line_number]
            line_diff << [row[:word_id], e, [row[:page_number], row[:line_number]]]
          end
        end
        report[:compare] = { mushaf_id: @compare_mushaf_id, rows: @rows.count { |r| r[:word_id] }, missing_in_existing: missing,
                             page_mismatches: page_diff.size, line_mismatches: line_diff.size,
                             page_mismatch_pages: page_diff.map { |d| d[2][0] }.uniq.sort,
                             line_mismatch_pages: line_diff.map { |d| d[2][0] }.uniq.sort,
                             sample: (page_diff + line_diff).first(20) }
        log("  compare with mushaf #{@compare_mushaf_id}: #{page_diff.size} page and #{line_diff.size} line mismatches over #{report[:compare][:rows]} rows")
      end

      def summarize
        report[:stats] = {
          printed_words: @data['words'].size,
          word_rows: @stats[:words],
          distinct_word_ids: @rows.select { |r| r[:char_type_name] == 'word' }.map { |r| r[:word_id] }.uniq.size,
          markers: @stats[:markers],
          markers_without_word: @stats[:markers_without_word],
          counted_ayahs: @data['ayah_starts'].size,
          surah_headers: @alignments.count { |a| a[2] == :surah_name },
          basmalah_lines: @alignments.count { |a| a[2] == :bismillah },
          text_lines: @data['line_starts'].size
        }
        warn("markers #{@stats[:markers]} != counted ayahs #{@data['ayah_starts'].size}") if @stats[:markers] != @data['ayah_starts'].size && report[:unmapped_positions].empty?
      end

      def write_review
        return unless @review_path

        FileUtils.mkdir_p(@review_path.dirname)
        @review_path.write(JSON.pretty_generate(report.merge(generated_at: Time.now.utc.iso8601, numbering: @numbering.slug, script: @script.slug)))
        log("  review written to #{@review_path}")
      end

      # ---------------------------------------------------------------- write

      def write
        @mushaf = upsert_mushaf
        MushafWord.where(mushaf_id: @mushaf.id).delete_all
        MushafLineAlignment.where(mushaf_id: @mushaf.id).delete_all
        @rows.each_slice(BATCH).with_index do |slice, i|
          MushafWord.insert_all!(slice.map { |r| r.merge(mushaf_id: @mushaf.id) })
          log("  #{key}: wrote #{[(i + 1) * BATCH, @rows.size].min}/#{@rows.size} rows")
        end
        now = Time.current
        MushafLineAlignment.insert_all!(@alignments.map do |page, line, kind, surah|
          meta = case kind
                 when :surah_name then { 'surah-name' => true, 'surah-number' => surah }
                 when :bismillah then { 'center' => true, 'bismillah' => true }
                 else { 'center' => true }
                 end
          { mushaf_id: @mushaf.id, page_number: page, line_number: line, alignment: kind.to_s, meta_data: meta, properties: meta, created_at: now, updated_at: now }
        end)
        pages = @mushaf.mushaf_pages.index_by(&:page_number)
        (1..report[:pages]).each { |n| pages[n] ||= @mushaf.mushaf_pages.create!(page_number: n) }
        @mushaf.update_pages_stats
        @page_lines.each { |page, n| pages[page].update_column(:lines_count, n) }
        report[:mushaf_id] = @mushaf.id
        log("  mushaf #{@mushaf.id} (#{@mushaf.name}): #{@rows.size} rows, #{@alignments.size} line alignments, #{report[:pages]} pages")
      end

      def upsert_mushaf
        name = "KFGQPC #{@data['mushaf']['name_en']}"
        # a rebuilt layout is 'generated' again until it is re-verified, so a mushaf already svg-verified is rebuilt in place, not duplicated
        m = Mushaf.find_by(script_id: @script.id, layout_source: Mushaf::GENERATED_LAYOUT_SOURCES) || Mushaf.new(script_id: @script.id)
        rc = layout_resource_content(m, "qpc-#{key}-15-lines")
        rc.assign_attributes(name: "#{name} layout", sub_type: ResourceContent::SubType::Layout, resource_type: 'Mushaf',
                             cardinality_type: ResourceContent::CardinalityType::OnePage, approved: false)
        # the editor's proofreading view shows mushaf.pdf_url page N+1 for mushaf page N (pdf.quran.ws has a cover page)
        rc.meta_data = (rc.meta_data || {}).merge('source-pdf-page-offset' => 1)
        rc.save!
        m.assign_attributes(
          name: name,
          description: "#{@data['mushaf']['name_ar']} — 15-line layout generated from quran-text #{key} (#{@data['generated']}) and the Complex's #{@data.dig('provenance', 'layout', 'member') || 'release'}; review before enabling.",
          lines_per_page: LINES_PER_PAGE, pages_count: @pages_count || report[:pages],
          default_font_name: @script.font_css_class, riwayah: @riwayah, script: @script, numbering: @numbering,
          enabled: false, is_default: false, layout_source: 'generated',
          pdf_url: self.class.pdf_url(key), source_package: @data.dig('provenance', 'layout', 'package') || @data.dig('provenance', 'text', 'package'),
          resource_content: rc
        )
        m.save!
        m.update_columns(resource_content_id: rc.id) if m.resource_content_id != rc.id # the column the admin and exports read, next to the polymorphic link
        m
      end

      # The layout resource of the generated mushaf: its own when it has one,
      # else the one named by the slug — unless that slug already belongs to a
      # hand-made layout (qpc-hafs-15-lines is mushaf 5's), in which case the
      # generated mushaf gets a resource of its own. Slugs are not unique.
      def layout_resource_content(mushaf, slug)
        owned_by_another = ->(rc) { Mushaf.where(resource_content_id: rc.id).where.not(id: mushaf.id).exists? }
        rc = mushaf.resource_content_id && ResourceContent.find_by(id: mushaf.resource_content_id)
        rc = nil if rc && owned_by_another.call(rc)
        rc ||= ResourceContent.find_by(slug: slug)
        rc = nil if rc && owned_by_another.call(rc)
        rc || ResourceContent.new(slug: ResourceContent.exists?(slug: slug) ? "#{slug}-generated" : slug)
      end
    end
  end
end
