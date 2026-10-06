# frozen_string_literal: true

require 'json'
require 'digest'

module Qiraat
  module Import
    # Imports one quran-text edition (data/mushaf/<key>.json) as a Script
    # stored in word_texts (P3.3).
    #
    # The edition file lists its printed words by position with a numbering
    # block that maps positions onto the shared numbers (1..77434): walk the
    # words, skip the numbers the edition does not read (`missing`) and let a
    # `written_joined` position cover a run of numbers. Each shared number is
    # then a QUL words row (words.number, or a number_last range where one
    # Hafs row covers two numbers), and the edition's form becomes one
    # word_texts row for (script, word). Where two edition words land on one
    # QUL row (Hafs writes them joined, e.g. 72:16:1), their forms are joined
    # with a space, the same convention QUL already uses at 37:130.
    #
    # Marks (waqf signs, ۩, ۞) are kept out of `words[]` upstream; the
    # printed form is rebuilt per layers.text: "after" marks are appended with
    # no space, "before" marks (۞) are recorded in `marks` only. Text is
    # copied byte for byte; nothing is normalised.
    #
    # Idempotent: the script row is matched by slug and every word_texts row
    # is upserted on its key; rows no longer produced are deleted.
    class ScriptText
      BATCH = 5000

      # quran-text edition key => [QUL script slug, riwayah slug, existing QUL font-face class]
      EDITIONS = {
        'hafs' => ['qpc-hafs-quran-text', 'hafs', 'qpc-hafs'],
        'shubah' => ['qpc-shubah', 'shuba', 'qpc-shuba'],
        'warsh' => ['qpc-warsh', 'warsh', 'qpc-warsh'],
        'qalun' => ['qpc-qalun', 'qalun', 'qpc-qaloun'],
        'duri' => ['qpc-duri', 'duri', 'qpc-douri'],
        'susi' => ['qpc-susi', 'susi', 'qpc-sousi'],
        'bazzi' => ['qpc-bazzi', 'bazzi', 'qpc-bazzi']
      }.freeze

      attr_reader :key, :path, :report, :script

      def initialize(key:, path:, dry_run: false, logger: $stdout)
        @key = key
        @path = Pathname(path)
        @dry_run = dry_run
        @logger = logger
        @report = { edition: key, printed_words: 0, numbers_read: 0, rows: 0, joined_rows: [], spanning_rows: [], missing_numbers: [], unmapped_numbers: [], written: 0, deleted: 0 }
      end

      def call
        slug, riwayah_slug, css = EDITIONS.fetch(key) { raise ArgumentError, "unknown quran-text edition #{key}" }
        data = JSON.parse(path.read)
        rows = build_rows(data)
        report[:printed_words] = data['words'].size
        report[:missing_numbers] = data['numbering']['missing']
        report[:rows] = rows.size
        return report if @dry_run

        @script = upsert_script(data, slug, riwayah_slug, css)
        write_rows(rows)
        @script.update!(text_sha256: text_digest(data, rows), enabled: false) if @script.text_sha256.nil? || @script.text_sha256 != text_digest(data, rows)
        report
      end

      private

      def log(msg)
        @logger&.puts(msg)
      end

      # [{word_id:, text:, marks:, numbers: [...]}] in edition order
      def build_rows(data)
        numbers_by_position = positions_to_numbers(data)
        marks_by_position = marks_by_position(data)
        words_by_number = words_by_number_map
        by_word = {} # word_id => row (joined when two edition words hit one QUL row)
        data['words'].each_with_index do |form, pos|
          nums = numbers_by_position[pos]
          report[:numbers_read] += nums.size
          after, before = marks_by_position[pos] || [[], []]
          text = form + after.join
          word_id = nums.map { |n| words_by_number[n] }.compact.uniq
          if word_id.empty?
            report[:unmapped_numbers].concat(nums)
            next
          end
          # One printed word covering numbers QUL keeps as separate rows (Duri and
          # Susi write 73:20 أَلَّن as one word over 74226-74227): the form goes on
          # the first row and the later rows get no row for this script.
          report[:spanning_rows] << [pos, word_id] if word_id.size > 1
          word_id = word_id.first
          if (row = by_word[word_id])
            row[:text] = "#{row[:text]} #{text}"
            row[:marks].concat(after + before)
            row[:numbers].concat(nums)
            report[:joined_rows] << word_id
          else
            by_word[word_id] = { word_id: word_id, text: text, marks: after + before, numbers: nums.dup }
          end
        end
        by_word.values
      end

      # Position => [numbers], per the quran-text numbering block.
      def positions_to_numbers(data)
        missing = data['numbering']['missing'].to_set
        joined = data['numbering']['written_joined'].to_h { |j| [j['position'], j['numbers']] }
        counter = 1
        data['words'].each_index.map do |pos|
          counter += 1 while missing.include?(counter)
          if (run = joined[pos])
            counter = run.max + 1
            run
          else
            n = counter
            counter += 1
            [n]
          end
        end
      end

      # Position => [[after signs], [before signs]]
      def marks_by_position(data)
        types = data['mark_types']
        out = Hash.new { |h, k| h[k] = [[], []] }
        data['marks'].each do |pos, type_index|
          t = types[type_index]
          out[pos][t['side'] == 'before' ? 1 : 0] << t['sign']
        end
        out
      end

      # Shared number => QUL words.id, including number_last ranges.
      def words_by_number_map
        map = {}
        Word.unscoped.where.not(number: nil).pluck(:id, :number, :number_last).each do |id, n, last|
          (n..(last || n)).each { |x| map[x] = id }
        end
        map
      end

      def upsert_script(data, slug, riwayah_slug, css)
        riwayah = Riwayah.find_by!(slug: riwayah_slug)
        row = Script.find_or_initialize_by(slug: slug)
        row.assign_attributes(
          name: "KFGQPC #{data['mushaf']['name_en']} (quran-text #{key})",
          riwayah: riwayah, kind: 'unicode', storage: 'rows', column_name: nil,
          font_family: css, font_css_class: css,
          source_package: data['provenance']['text']['package'],
          source_sha256: data['provenance']['text']['sha256'],
          release_year: data['provenance']['text']['release_year'],
          licence: 'KFGQPC terms (text); quran-text CC BY 4.0 (work)',
          enabled: row.new_record? ? false : row.enabled,
          meta_data: row.meta_data.merge(
            'quran_text_key' => key,
            'publisher_font_family' => data['font']['family'],
            'font_file' => data['font']['file'],
            'font_sha256' => data['font']['sha256'],
            'counting_system' => data['counting']['system'],
            'counting_system_printed' => data['counting']['system_printed'],
            'ayah_count' => data['counting']['ayah_count'],
            'basmalah_counted' => data['counting']['basmalah_counted'],
            'word_count' => data['mushaf']['word_count'],
            'text_sha256_method' => 'sha256 over the edition words with after-marks reattached, joined by newline, one ayah per line in edition order'
          )
        )
        row.save!
        row
      end

      def write_rows(rows)
        keep = rows.map { |r| r[:word_id] }
        rows.each_slice(BATCH) do |slice|
          WordText.upsert_all(
            slice.map { |r| { script_id: script.id, word_id: r[:word_id], text: r[:text], marks: r[:marks] } },
            unique_by: %i[script_id word_id]
          )
          report[:written] += slice.size
          log("  #{key}: wrote #{report[:written]}")
        end
        report[:deleted] = WordText.where(script_id: script.id).where.not(word_id: keep).delete_all
      end

      # Digest of the printed ayah texts in edition order (ayah_starts slices
      # over words with after-marks), so a timing or span set can state which
      # text it was measured against.
      def text_digest(data, _rows)
        marks = marks_by_position(data)
        words = data['words'].each_with_index.map { |w, i| w + (marks[i] ? marks[i][0].join : '') }
        starts = data['ayah_starts']
        lines = starts.each_with_index.map { |s, i| words[s...(starts[i + 1] || words.size)].join(' ') }
        Digest::SHA256.hexdigest(lines.join("\n"))
      end
    end
  end
end
