# frozen_string_literal: true

module Qiraat
  module Import
    # How a quran-text edition file (data/mushaf/<key>.json) addresses its
    # printed words, shared by the script importer (P3.3) and the layout
    # generator (P5.3).
    #
    # words[] lists the printed words by position. The `numbering` block maps
    # positions onto the shared numbers 1..77434: `missing` are numbers the
    # edition does not read, `written_joined` are positions that cover a run
    # of numbers. Marks (waqf signs, ۩, ۞) are kept out of words[] and listed
    # by position in `marks`.
    module EditionWords
      # Position => [shared numbers], per the quran-text numbering block.
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

      # The printed form at a position: after-marks appended with no space,
      # before-marks (۞) written before the word with a space, as the release
      # prints them and as QUL already stores "۞ إِنَّ" for Hafs.
      def printed_form(data, marks, pos)
        after, before = marks[pos] || [[], []]
        text = data['words'][pos] + after.join
        before.empty? ? text : "#{before.join(' ')} #{text}"
      end

      # Shared number => QUL words.id, including number_last ranges.
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
