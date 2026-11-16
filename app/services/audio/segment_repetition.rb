# frozen_string_literal: true

require 'set'
require_relative 'segment_normalizer'

module Audio
  # Finds repeats in recited word lists ([[word, from_ms, to_ms], ...] in
  # recitation order). Plain Ruby so it can be tested without Rails;
  # Audio::Segment delegates to it.
  #
  # Two kinds of repeat:
  #   within an ayah   1 2 3 4 5 | 3 4 5 6          → words 3–5
  #   back to an ayah  27, 28, then 27 again          → stored in 27's word list,
  #                    with a time gap that holds 28's words
  module SegmentRepetition
    module_function

    # Every return to an earlier ayah in one surah.
    #
    #   rows → [[verse_number, word_list], ...] for the whole surah
    #   →      { verse_number => [{ after_word:, back_to_word:, gap_from:, gap_to:, ayahs: }] }
    def cross_ayah_returns(rows)
      words = rows.to_h do |vn, segs|
        list = (Audio::SegmentNormalizer.parse(segs) || segs)
        list = Array(list).select { |w| w.is_a?(Array) && w.size >= 3 && w[1].is_a?(Numeric) && w[2].is_a?(Numeric) }
        [vn, list.map { |w| [w[0].to_i, w[1].to_f, w[2].to_f] }]
      end
      # Every real word of the surah by start time, to find what lies in a gap.
      timeline = words.flat_map { |vn, list| list.select { |w| w[2] > w[1] }.map { |w| [w[1], w[2], vn] } }.sort
      starts = timeline.map(&:first)

      words.each_with_object({}) do |(vn, list), found|
        list.each_cons(2) do |a, b|
          next unless b[1] > a[2]

          from = starts.bsearch_index { |t| t >= a[2] } || starts.size
          ayahs = []
          while from < starts.size && starts[from] < b[1]
            start, finish, other = timeline[from]
            ayahs << other if other != vn && start >= a[2] && finish <= b[1]
            from += 1
          end
          next if ayahs.empty?

          (found[vn] ||= []) << { after_word: a[0], back_to_word: b[0], gap_from: a[2].to_i, gap_to: b[1].to_i,
                                  ayahs: ayahs.uniq.sort }
        end
      end
    end

    # The word list cut where the reciter came back after other ayahs.
    def split_passes(list, returns)
      return [list] if returns.nil? || returns.empty?

      split_at = returns.map { |r| r[:gap_to].to_i }.to_set
      list.slice_before { |seg| split_at.include?(seg[1].to_i) }.to_a
    end

    # Repeated runs in one word list: [[from_word, to_word], ...].
    def within_repeats(list)
      positions = list.map { |s| s[0] }
      ranges = []
      seen = {}

      positions.each_with_index do |num, i|
        prev_index = seen[num]

        if prev_index
          length = i - prev_index
          # Alternating takes (1 2 1 2) also match shifted by one word as a
          # backwards "2-1" run; that is the same repeat, not a new one.
          if positions[prev_index, length] == positions[i, length] &&
             positions[i] <= positions[i + length - 1]
            ranges << [positions[i], positions[i + length - 1]]
          end
        end

        seen[num] = i
      end

      ranges.uniq
    end

    # Repeats within the ayah, counted per pass so that coming back after
    # other ayahs isn't also reported as the ayah's own words repeating.
    def within_repeats_by_pass(list, returns)
      split_passes(list, returns).flat_map { |pass| within_repeats(pass) }.uniq
    end
  end
end
