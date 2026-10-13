# frozen_string_literal: true

module Qiraat
  module Backfill
    # Sets mushafs.script_id by detecting which column-backed script each
    # mushaf's cached word text was copied from (P3.4).
    #
    # For every mushaf with cached words, one query counts how many cached
    # words differ from each column-backed script's column. The column with
    # the fewest differences wins when they are under MAX_STALE_SHARE of the
    # words; ties (code_v2 feeds qpc-v2 and qpc-v4-tajweed; Indopak and QPC
    # nastaleeq agree on most words) are broken by default_font_name, then by
    # the legacy fan-out list. Mushafs with no cached words, or whose text
    # matches nothing, are reported and left NULL so the legacy name matching
    # keeps serving them.
    #
    # Idempotent: an existing script_id is only reported, never overwritten
    # (FORCE=1 re-detects).
    class MushafScripts
      # Mismatches above this share of a mushaf's words mean "not this column"
      # even for the best candidate (the closest wrong column, QPC vs Indopak
      # nastaleeq, differs on 283 of 77,432 words = 0.37%; 1% keeps a margin
      # for the stale edits every cache carries).
      MAX_STALE_SHARE = 0.01

      # default_font_name hints that break ties between scripts sharing a column
      FONT_HINTS = {
        'v4-tajweed' => 'qpc-v4-tajweed',
        'v2' => 'qpc-v2',
        'v1' => 'qpc-v1'
      }.freeze

      # Decided from the full-table comparison (7 Oct 2026, quran_dev):
      #   23 "Indopak 13 lines - Taj company": 26 of 77,432 words differ from
      #      text_indopak_nastaleeq but 272 differ from text_qpc_nastaleeq, so the
      #      cache is indopak nastaleeq; the legacy fan-out that fed it from
      #      text_qpc_nastaleeq was wrong and the 26 words are stale edits.
      OVERRIDES = { 23 => 'indopak-nastaleeq' }.freeze

      # The fan-out list Word#update_mushaf_word_text used before P3.4 (dropped
      # from the model in P7.5): which mushafs each column fed. Kept here only
      # as a tie-break when a mushaf's cached text matches several columns.
      LEGACY_COLUMN_MUSHAFS = {
        'text_qpc_nastaleeq_hafs' => [14, 15], 'text_qpc_nastaleeq' => [23], 'text_indopak_nastaleeq' => [6, 7, 8, 17],
        'text_qpc_hafs' => [5, 27, 13], 'text_uthmani' => [4], 'text_indopak' => [3], 'code_v1' => [2], 'code_v2' => [1, 19],
        'text_uthmani_tajweed' => [16], 'text_qpc_hafs_tajweed' => [21], 'text_digital_khatt' => [20], 'text_digital_khatt_v1' => [22],
        'text_digital_khatt_indopak' => [24], 'text_indonesian_sign_language' => [31], 'text_indopak_misbah' => [32]
      }.freeze

      # Image mushafs cache a relative image path per word ("w/qa-color/2/255/5.png");
      # the path prefix names the image set.
      IMAGE_PREFIXES = { 'w/qa-color/' => 'tajweed-images-new', 'w/rq-color/' => 'tajweed-images-old', 'w/qa-black/' => 'black-images' }.freeze

      attr_reader :report

      def initialize(dry_run: false, force: false)
        @dry_run = dry_run
        @force = force
        @report = { assigned: {}, kept: {}, ambiguous: {}, unmatched: {}, no_words: [], stale: {} }
      end

      def call
        scripts = Script.column_backed.where(kind: %w[unicode glyph]).to_a
        Mushaf.order(:id).each do |mushaf|
          if mushaf.script_id && !@force
            report[:kept][mushaf.id] = mushaf.script.slug
            next
          end
          if (slug = OVERRIDES[mushaf.id])
            assign(mushaf, Script.find_by!(slug: slug))
            next
          end

          total = MushafWord.where(mushaf_id: mushaf.id, char_type_name: 'word').count
          if total.zero?
            # no cached words yet: the font name alone can name the script (31, Sign Language)
            by_font = Script.column_backed.find_by(font_css_class: mushaf.default_font_name)
            by_font ? assign(mushaf, by_font) : report[:no_words] << mushaf.id
            next
          end
          if mushaf.default_font_name == 'img'
            assign_image_script(mushaf)
            next
          end

          # One query per mushaf: how many cached words differ from each column.
          counts = mismatch_counts(mushaf, scripts)
          best = counts.min_by { |_, n| n }
          candidates = counts.select { |_, n| n == best.last }.keys
          if best.last > total * MAX_STALE_SHARE
            report[:unmatched][mushaf.id] = counts.sort_by { |_, n| n }.first(3).map { |sc, n| "#{sc.slug}:#{n}" }
            next
          end
          chosen = pick(candidates, mushaf)
          if chosen.nil?
            report[:ambiguous][mushaf.id] = candidates.map(&:slug)
            next
          end
          report[:stale][mushaf.id] = best.last
          assign(mushaf, chosen)
        end
        report
      end

      private

      def assign(mushaf, script)
        report[:assigned][mushaf.id] = script.slug
        mushaf.update_column(:script_id, script.id) unless @dry_run
      end

      # { script => number of cached words whose text differs from the column }
      def mismatch_counts(mushaf, scripts)
        conn = Word.connection
        selects = scripts.map { |s| "count(*) FILTER (WHERE mw.text IS DISTINCT FROM w.#{conn.quote_column_name(s.column_name)}) AS c#{s.id}" }
        row = conn.select_one(<<~SQL)
          SELECT #{selects.join(', ')}
          FROM mushaf_words mw JOIN words w ON w.id = mw.word_id
          WHERE mw.mushaf_id = #{mushaf.id.to_i} AND mw.char_type_name = 'word'
        SQL
        scripts.to_h { |s| [s, row["c#{s.id}"].to_i] }
      end

      def assign_image_script(mushaf)
        sample = MushafWord.where(mushaf_id: mushaf.id, char_type_name: 'word').where.not(text: [nil, '']).limit(50)
        prefixes = sample.map { |mw| IMAGE_PREFIXES.find { |pre, _| mw.text.to_s.start_with?(pre) }&.last }.uniq
        if prefixes.size == 1 && prefixes.first
          assign(mushaf, Script.find_by!(slug: prefixes.first))
        else
          report[:unmatched][mushaf.id] = prefixes
        end
      end

      def pick(matches, mushaf)
        return matches.first if matches.size == 1

        font = mushaf.default_font_name.to_s
        hinted = FONT_HINTS.find { |needle, _| font.include?(needle) }&.last
        by_font = matches.find { |s| s.slug == hinted }
        return by_font if by_font

        # Columns identical for this mushaf's words: the legacy fan-out list says
        # which column fed it.
        by_legacy = matches.select { |s| LEGACY_COLUMN_MUSHAFS.fetch(s.column_name, []).include?(mushaf.id) }
        by_legacy.size == 1 ? by_legacy.first : nil
      end
    end
  end
end
