# frozen_string_literal: true

require 'csv'

module Qiraat
  module Backfill
    # Inserts a words row for every shared number Hafs does not read (P2.3).
    #
    # quran-text numbers every word any of the seven printed riwayat reads. One
    # number has no Hafs coordinates in the pinned data: 25685, "مِن" in Kufi
    # 9:100, read by Bazzi alone ("تَجۡرِي مِن تَحۡتِهَا"). Such a word still needs a
    # row in the shared skeleton so riwayah forms, glosses and numberings can
    # attach to it. The row is placed after the nearest preceding Hafs word
    # (by shared number), with the same position and sub_position 1, 2, ...,
    # hafs_reads = false and no Hafs text. Idempotent: matched by number.
    class MissingWords
      Inserted = Struct.new(:number, :location, :verse_key, :after_location, keyword_init: true)

      attr_reader :csv_path, :report

      def initialize(csv_path:, dry_run: false)
        @csv_path = Pathname(csv_path)
        @dry_run = dry_run
        @report = { candidates: [], inserted: [], already_present: [], unplaceable: [] }
      end

      def call
        numbers = CSV.foreach(csv_path, headers: true, encoding: 'utf-8')
                     .select { |r| r['hafs_surah'].to_s.empty? }
                     .map { |r| r['number'].to_i }
        report[:candidates] = numbers
        numbers.each { |number| place(number) }
        report
      end

      private

      def place(number)
        if (existing = Word.unscoped.find_by(number: number))
          report[:already_present] << existing.location
          return
        end

        prev = preceding_word(number)
        unless prev
          report[:unplaceable] << number
          return
        end

        siblings = Word.unscoped.where(verse_id: prev.verse_id, position: prev.position).where.not(sub_position: 0)
        sub_position = siblings.maximum(:sub_position).to_i + 1
        location = "#{prev.verse_key}:#{prev.position}.#{sub_position}"
        report[:inserted] << Inserted.new(number: number, location: location, verse_key: prev.verse_key, after_location: prev.location)
        return if @dry_run

        Word.unscoped.create!(
          verse_id: prev.verse_id,
          chapter_id: prev.chapter_id,
          verse_key: prev.verse_key,
          char_type_id: prev.char_type_id,
          char_type_name: 'word',
          position: prev.position,
          sub_position: sub_position,
          location: location,
          number: number,
          hafs_reads: false
          # sequence_number and word_index stay NULL: both are Hafs orderings
        )
      end

      # The nearest smaller shared number that a Hafs word carries (a run of
      # missing numbers is walked back one by one).
      def preceding_word(number)
        n = number - 1
        while n.positive?
          w = Word.unscoped.where(char_type_name: 'word').where('number = :n OR (number_last IS NOT NULL AND :n BETWEEN number AND number_last)', n: n).first
          return w if w

          n -= 1
        end
        nil
      end
    end
  end
end
