# frozen_string_literal: true

module Qiraat
  module Import
    # Fills ayah_texts for row-backed scripts (P4.3): for every ayah of the
    # script's riwayah default numbering (the unnumbered basmalah included),
    # the word_texts forms in order joined by a space, with a ۞ (rub' sign,
    # the one "before" mark) printed before the word it precedes.
    # Idempotent: a script's rows are rebuilt on every run.
    class AyahTexts
      attr_reader :report

      def initialize(scripts: nil, dry_run: false)
        @scripts = scripts
        @dry_run = dry_run
        @report = {}
      end

      def call
        scope = Script.row_backed.includes(:riwayah).order(:id)
        scope = scope.where(slug: @scripts) if @scripts
        scope.each do |script|
          numbering = script.riwayah&.default_numbering
          unless numbering
            report[script.slug] = { error: 'riwayah has no default numbering' }
            next
          end

          rows = rows_for(script, numbering)
          report[script.slug] = { numbering: numbering.slug, ayahs: rows.size, empty: rows.count { |r| r[:text].blank? } }
          next if @dry_run

          AyahText.where(script_id: script.id).delete_all
          rows.reject { |r| r[:text].blank? }.each_slice(2000) { |slice| AyahText.insert_all!(slice) }
        end
        report
      end

      private

      def rows_for(script, numbering)
        # one query for all forms of the script, keyed by word id
        forms = WordText.where(script_id: script.id).pluck(:word_id, :text, :marks).to_h { |id, text, marks| [id, [text, marks]] }
        # shared number -> word id (a Hafs row covering two numbers maps both)
        by_number = {}
        Word.unscoped.where(char_type_name: 'word').where.not(number: nil).pluck(:id, :number, :number_last).each do |id, n, nl|
          (n..(nl || n)).each { |x| by_number[x] = id }
        end
        numbering.numbered_ayahs.in_order.pluck(:id, :first_number, :last_number).map do |ayah_id, first, last|
          ids = (first..last).map { |n| by_number[n] }.compact.uniq
          text = ids.filter_map do |wid|
            form, marks = forms[wid]
            next unless form

            marks.include?('۞') ? "۞ #{form}" : form
          end.join(' ')
          { script_id: script.id, ayah_id: ayah_id, text: text }
        end
      end
    end
  end
end
