# frozen_string_literal: true

require 'csv'

module Qiraat
  module Backfill
    # Writes the quran-text shared word number onto words.number (P2.2).
    #
    # Alignment is per Kufi ayah. quran-text gives each shared number the Hafs
    # coordinates {surah, ayah, position}; QUL gives each word row a location
    # "surah:ayah:position". In 6,233 ayahs the two sides have the same number
    # of words and align by position. Three ayahs differ in segmentation and
    # are aligned by text instead (spaces removed, NFC on both sides):
    #
    #   72:16  Hafs prints numbers 73950 and 73951 as one word (quran-text
    #          written_joined): one QUL row gets number=73950, number_last=73951.
    #   37:130 QUL keeps "إِلۡ يَاسِينَ" as one row with a space; quran-text has
    #          two numbers: the row gets number and number_last.
    #   15:7   QUL splits "لَّوۡمَا" into two rows; quran-text has one number:
    #          the first row gets the number, the second stays NULL (continuation).
    #
    # Ayah-end rows (char_type_name = "end") are never numbered. Idempotent:
    # every run recomputes the full assignment and writes it with one
    # UPDATE ... FROM (VALUES ...) per batch.
    class WordNumbers
      BATCH = 5000

      Row = Struct.new(:number, :surah, :ayah, :position, :form, :joined_hafs, keyword_init: true)

      attr_reader :csv_path, :report

      def initialize(csv_path:, dry_run: false, logger: $stdout)
        @csv_path = Pathname(csv_path)
        @dry_run = dry_run
        @logger = logger
        @report = {
          index_rows_with_hafs: 0, index_rows_without_hafs: [],
          qul_word_rows: 0, numbered: 0, with_number_last: [], continuation: [],
          text_aligned_ayahs: [], unaligned_ayahs: [], text_mismatches: 0, text_mismatch_samples: [], written: 0
        }
      end

      def call
        index = load_index
        assignments = []
        Verse.unscoped.order(:id).includes(:words).each do |verse|
          qul = verse.words.to_a.select { |w| w.char_type_name == 'word' }.sort_by(&:position)
          report[:qul_word_rows] += qul.size
          rows = index[verse.verse_key] || []
          assignments.concat(align(verse.verse_key, qul, rows))
        end
        write(assignments) unless @dry_run
        report[:numbered] = assignments.count { |a| a[:number] }
        report
      end

      private

      def log(msg)
        @logger.puts(msg) if @logger
      end

      def load_index
        by_key = Hash.new { |h, k| h[k] = [] }
        CSV.foreach(csv_path, headers: true, encoding: 'utf-8') do |r|
          if r['hafs_surah'].to_s.empty?
            report[:index_rows_without_hafs] << r['number'].to_i
            next
          end
          report[:index_rows_with_hafs] += 1
          by_key["#{r['hafs_surah']}:#{r['hafs_ayah']}"] << Row.new(
            number: r['number'].to_i, surah: r['hafs_surah'].to_i, ayah: r['hafs_ayah'].to_i,
            position: r['hafs_position'].to_i, form: r['form_hafs'].to_s,
            joined_hafs: r['written_joined'].to_s.include?('hafs')
          )
        end
        by_key.each_value { |rows| rows.sort_by! { |x| [x.position, x.number] } }
        by_key
      end

      # Returns [{id:, number:, number_last:}] for every QUL word row of the ayah.
      def align(key, qul, rows)
        groups = rows.group_by(&:position).sort.map { |_pos, g| g.sort_by(&:number) } # one group per Hafs position
        if groups.size == qul.size
          qul.each_with_index.map do |w, i|
            nums = groups[i].map(&:number)
            unless same_text?(w.text_qpc_hafs, groups[i].map(&:form).join)
              report[:text_mismatches] += 1
              report[:text_mismatch_samples] << [w.location, w.text_qpc_hafs, groups[i].map(&:form).join] if report[:text_mismatch_samples].size < 40
            end
            assignment(w, nums)
          end
        else
          align_by_text(key, qul, rows)
        end
      end

      # Greedy two-sided alignment on text with spaces removed. Consumes index
      # rows until their joined text covers the QUL word; when it overshoots,
      # the following QUL rows that complete the text are continuations.
      def align_by_text(key, qul, rows)
        report[:text_aligned_ayahs] << key
        out = []
        i = 0
        j = 0
        while j < qul.size
          word = qul[j]
          target = fold(word.text_qpc_hafs)
          acc = +''
          nums = []
          while i < rows.size && acc.length < target.length
            acc << fold(rows[i].form)
            nums << rows[i].number
            i += 1
          end
          return unaligned(key, qul) unless acc.start_with?(target)

          out << assignment(word, nums)
          j += 1
          rest = acc[target.length..]
          while !rest.empty? && j < qul.size && rest.start_with?(fold(qul[j].text_qpc_hafs))
            rest = rest[fold(qul[j].text_qpc_hafs).length..]
            out << assignment(qul[j], [])
            report[:continuation] << qul[j].location
            j += 1
          end
          return unaligned(key, qul) unless rest.empty?
        end
        return unaligned(key, qul) unless i == rows.size

        out
      end

      def unaligned(key, qul)
        report[:unaligned_ayahs] << key
        qul.map { |x| assignment(x, []) }
      end

      def assignment(word, nums)
        nums = nums.sort
        report[:with_number_last] << word.location if nums.size > 1
        { id: word.id, number: nums.first, number_last: (nums.size > 1 ? nums.last : nil) }
      end

      def fold(text)
        text.to_s.unicode_normalize(:nfc).delete(' ')
      end

      # Letters only: QUL attaches waqf signs to the word, prints tanween with
      # different code points and seats a kashida (U+0640) in كَلَّا; quran-text
      # keeps marks in a separate layer and has no kashida.
      MARKS = /[\u064B-\u065F\u0670\u0640\u06D6-\u06ED\u08D3-\u08FF\u0610-\u061A\s]/

      def same_text?(a, b)
        fold(a).gsub(MARKS, '') == fold(b).gsub(MARKS, '')
      end

      def write(assignments)
        conn = Word.connection
        conn.execute("UPDATE #{Word.quoted_table_name} SET number = NULL, number_last = NULL WHERE number IS NOT NULL OR number_last IS NOT NULL")
        assignments.select { |a| a[:number] }.each_slice(BATCH) do |slice|
          values = slice.map { |a| "(#{a[:id].to_i}, #{a[:number].to_i}, #{a[:number_last] ? a[:number_last].to_i : 'NULL'}::integer)" }.join(', ')
          conn.execute(<<~SQL)
            UPDATE #{Word.quoted_table_name} AS w
            SET number = v.number::integer, number_last = v.number_last::integer
            FROM (VALUES #{values}) AS v(id, number, number_last)
            WHERE w.id = v.id
          SQL
          report[:written] += slice.size
          log("  wrote #{report[:written]}")
        end
      end
    end
  end
end
