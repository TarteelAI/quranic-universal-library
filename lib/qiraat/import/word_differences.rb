# frozen_string_literal: true

require 'json'

module Qiraat
  module Import
    # Loads quran-text data/differences.json into word_differences (P3.5).
    #
    # Each entry is a shared number with the forms per riwayah. The number
    # maps to a QUL words row (words.number or a number_last range); riwayah
    # keys are converted to QUL slugs (shubah -> shuba). Idempotent: rows are
    # upserted on word_id and rows no longer in the file are deleted.
    class WordDifferences
      # quran-text riwayah key => QUL riwayah slug
      SLUGS = { 'hafs' => 'hafs', 'shubah' => 'shuba', 'warsh' => 'warsh', 'qalun' => 'qalun', 'duri' => 'duri', 'susi' => 'susi', 'bazzi' => 'bazzi' }.freeze

      attr_reader :path, :report

      def initialize(path:, dry_run: false)
        @path = Pathname(path)
        @dry_run = dry_run
        @report = { in_file: 0, rows: 0, merged: [], unmapped: [], by_status: Hash.new(0), deleted: 0 }
      end

      def call
        data = JSON.parse(path.read)
        words_by_number = words_by_number_map
        rows = data['words'].filter_map do |w|
          report[:in_file] += 1
          word_id = words_by_number[w['number']]
          unless word_id
            report[:unmapped] << w['number']
            next
          end
          report[:by_status][w['status']] += 1
          {
            word_id: word_id,
            chapter_id: w['surah'],
            status: w['status'],
            groups: (w['groups'] || single_group(w)).map { |g| { 'text' => g['text'], 'riwayahs' => g['riwayahs'].map { |k| SLUGS.fetch(k) } } },
            missing: (w['missing'] || []).map { |k| SLUGS.fetch(k) },
            written_joined: (w['written_joined'] || []).map { |k| SLUGS.fetch(k) },
            created_at: Time.current, updated_at: Time.current
          }
        end
        # Two shared numbers Hafs writes as one word (73950, 73951 at 72:16:1)
        # share one QUL row: keep the first entry, note the other.
        seen = {}
        rows = rows.select do |r|
          if seen[r[:word_id]]
            report[:merged] << r[:word_id]
            false
          else
            seen[r[:word_id]] = true
          end
        end
        report[:rows] = rows.size
        return report if @dry_run

        WordDifference.upsert_all(rows, unique_by: :word_id) if rows.any?
        report[:deleted] = WordDifference.where.not(word_id: rows.map { |r| r[:word_id] }).delete_all
        report
      end

      private

      # Entries without `groups` have one spelling for every riwayah that reads the word.
      def single_group(w)
        forms = w['forms'] || {}
        return [] if forms.empty?

        [{ 'text' => forms.values.first, 'riwayahs' => forms.keys }]
      end

      def words_by_number_map
        map = {}
        Word.unscoped.where.not(number: nil).pluck(:id, :number, :number_last).each do |id, n, last|
          (n..(last || n)).each { |x| map[x] = id }
        end
        map
      end
    end
  end
end
