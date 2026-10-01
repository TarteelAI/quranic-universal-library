module Morphology
  module NoorBayan
    # NoorBayan's `uthmani_token` column carries no tashkeel for chapters 9-58:
    #
    # The mushaf stores one string per *word*, while NoorBayan splits a word into
    # prefix / stem / suffix tokens. This class re-slices a verse's real script
    # back onto those tokens, so each token keeps exactly the letters and marks
    # that belong to it.
    #
    # It works on consonant skeletons (letters with every combining mark removed
    # and near-identical letter shapes folded together). ~95% of verses match
    # character-for-character and take the fast path; the rest go through a
    # Needleman-Wunsch alignment, which absorbs the handful of spelling
    # disagreements between the two sources (e.g. NoorBayan writes "ءا" where
    # the mushaf writes "أٓ", and the two disagree on a few word boundaries such
    # as 2:181 "بعدما").
    #
    #   ScriptAligner.new('مَرۡجِعُكُمۡۖ').split(['مرْجعُ', 'كُمْ'])
    #   # => ['مَرۡجِعُ', 'كُمۡۖ']
    #
    # Returns nil in a slot it cannot place, so callers can fall back to the
    # original NoorBayan text rather than render an empty token.
    class ScriptAligner
      # Combining marks and tatweel: everything that hangs off a letter rather
      # than being one. Includes U+0670 (dagger alif) and the waqf signs.
      MARKS = /[ؐ-ًؚ-ٰٟۖ-ۭـ]/

      # Maddah. The mushaf writes alef-maddah as one letter plus this mark
      # ("أٓخِرَة", or the precomposed "آ"); NoorBayan spells the same
      # sound out as hamza + alif ("ءَاخِرَة"). Expanding the mushaf side to
      # two skeleton slots makes the two agree.
      MADDAH = "ٓ".freeze

      # Short vowels, tanween, shadda and sukun - the marks a mark-only token
      # can stand for. Narrower than MARKS, which also covers waqf signs.
      VOWELS = /[\u064B-\u0652\u0670\u06E1]/

      # Letter shapes the two sources spell differently but that denote the same
      # consonant slot, folded so skeletons compare equal.
      LETTER_FOLD = {
        'ٱ' => 'ا', 'أ' => 'ا', 'إ' => 'ا', 'آ' => 'ا',
        'ى' => 'ي', 'ئ' => 'ي',
        'ؤ' => 'و',
        'ة' => 'ه'
      }.freeze

      def initialize(verse_text)
        @verse_text = verse_text.to_s
        @verse_bases = self.class.base_chars(@verse_text)
      end

      # segments: NoorBayan token texts for this verse's surface tokens, in
      # reading order. Returns one slice of the real script per segment.
      def split(segments)
        return Array.new(segments.size) if @verse_bases.empty?

        segment_bases = segments.map { |s| self.class.base_chars(s).map(&:first) }
        starts = segment_start_offsets(segments, segment_bases)
        slice_at(starts, segments.size)
      end

      # [[folded_char, index_in_str], ...] for every letter, marks dropped.
      # A maddah-bearing alif yields two entries (hamza + alif) that share the
      # one source index, so it lines up with how NoorBayan spells it.
      def self.base_chars(str)
        text = str.to_s
        chars = []
        text.each_char.with_index do |c, i|
          next if c =~ MARKS || c == ' '

          if c == 'آ' || text[i + 1] == MADDAH
            chars << ['ء', i]
            chars << ['ا', i]
          else
            chars << [LETTER_FOLD.fetch(c, c), i]
          end
        end
        chars
      end

      private

      # For each segment, the index in @verse_text where its first letter sits
      # (nil when the aligner could not place the segment at all).
      def segment_start_offsets(segments, segment_bases)
        flat = segment_bases.flatten(1)
        pairs =
          if flat == @verse_bases.map(&:first)
            flat.each_index.map { |i| [i, i] }
          else
            self.class.align(flat, @verse_bases.map(&:first))
          end

        # flat-position -> index in the real string
        flat_to_offset = {}
        pairs.each do |from, to|
          next if from.nil? || to.nil?

          flat_to_offset[from] = @verse_bases[to][1]
        end

        cursor = 0
        starts = segment_bases.map do |bases|
          first = (cursor...(cursor + bases.size)).filter_map { |i| flat_to_offset[i] }.min
          cursor += bases.size
          first
        end

        place_markless_segments(segments, segment_bases, starts)
      end

      # NoorBayan splits some words into a stem plus a mark-only suffix: the
      # possessive ya of "\u0631\u064e\u0628\u0651\u0650" is annotated as its own token whose text is just
      # the kasra. Those carry no letter to anchor, so they take the last
      # vowel mark before whatever follows them, and the stem stops short of it.
      def place_markless_segments(segments, segment_bases, starts)
        starts.each_index do |i|
          next unless segment_bases[i].empty?

          # A token with no letters AND no vowel of its own (NoorBayan leaves a
          # handful of rows blank) has nothing to match on - leave it unplaced
          # rather than let it claim a mark belonging to its neighbour.
          wanted = segments[i].to_s.chars.reverse.find { |c| c =~ VOWELS }
          next if wanted.nil?

          upper = starts[(i + 1)...starts.size].compact.first || @verse_text.length
          lower = starts[0...i].compact.last || 0
          window = (lower + 1...upper).to_a.reverse

          # Prefer the same mark the token itself spells, so a kasra token lands
          # on the kasra even when the mushaf orders shadda and kasra the other
          # way round; fall back to the last vowel mark in the window.
          starts[i] = window.find { |j| same_mark?(@verse_text[j], wanted) } ||
                      window.find { |j| @verse_text[j] =~ VOWELS }
        end
        starts
      end

      # The mushaf writes sukun as U+06E1 where NoorBayan writes U+0652.
      def same_mark?(left, right)
        fold_mark(left) == fold_mark(right)
      end

      def fold_mark(char)
        char == "\u0652" ? "\u06E1" : char
      end

      # Each segment runs from its own first letter up to the next segment's
      # first letter, so trailing diacritics and waqf marks stay with the token
      # they belong to. The last segment runs to the end of the verse text.
      def slice_at(starts, size)
        Array.new(size) do |i|
          from = starts[i]
          next nil if from.nil?

          to = starts[(i + 1)...size].compact.first || @verse_text.length
          next nil if to <= from

          text = @verse_text[from...to].strip
          text.empty? ? nil : text
        end
      end

      # Needleman-Wunsch with unit costs. Returns [a_index_or_nil, b_index_or_nil]
      # pairs in order.
      def self.align(a, b)
        n = a.size
        m = b.size
        dist = Array.new(n + 1) { Array.new(m + 1, 0) }
        (0..n).each { |i| dist[i][0] = i }
        (0..m).each { |j| dist[0][j] = j }

        (1..n).each do |i|
          row = dist[i]
          prev = dist[i - 1]
          (1..m).each do |j|
            cost = a[i - 1] == b[j - 1] ? 0 : 1
            row[j] = [prev[j] + 1, row[j - 1] + 1, prev[j - 1] + cost].min
          end
        end

        i = n
        j = m
        pairs = []
        while i.positive? || j.positive?
          if i.positive? && j.positive? && dist[i][j] == dist[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
            pairs << [i - 1, j - 1]
            i -= 1
            j -= 1
          elsif i.positive? && dist[i][j] == dist[i - 1][j] + 1
            pairs << [i - 1, nil]
            i -= 1
          else
            pairs << [nil, j - 1]
            j -= 1
          end
        end
        pairs.reverse
      end
    end
  end
end
