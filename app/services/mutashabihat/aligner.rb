module Mutashabihat
  # Finds the best matching stretch between a source phrase and an ayah
  # (Smith-Waterman local alignment), then labels every word of it.
  #
  # Word labels:
  #   exact    same word
  #   affix    a prefix or suffix differs (فكلوا / وكلوا, منها / من)
  #   form     same dictionary word, different form (يعملون / تعملون)
  #   root     same root, different word (أنزلنا / تنزيل)
  #   similar  sounds alike, same shape with a letter or two changed (فأنزلنا / فأرسلنا)
  #   changed  a different word in the same place (أنزلنا / أرسلنا)
  #   moved    the word is in both, at a different place (لعب ولهو / لهو ولعب)
  #   omitted  only the source has the word
  #   added    only the ayah has the word
  class Aligner
    SCORES = {
      exact: 4.0,
      affix: 3.0,
      form: 2.5,
      root: 1.0,
      similar: 1.0,
      changed: -2.0
    }.freeze
    GAP = -1.5
    SWAP_REACH = 3

    # Words that count towards "3 or more shared words"
    STRONG = %i[exact affix form moved].freeze

    Pair = Struct.new(:source, :target, :kind, keyword_init: true)

    def self.compare(a, b)
      return :exact if a.norm == b.norm
      return :affix if a.bare == b.bare || (a.stem_id && a.stem_id == b.stem_id)
      return :form if a.lemma_id && a.lemma_id == b.lemma_id
      return :root if a.root_id && a.root_id == b.root_id
      return :similar if sounds_alike?(a.norm, b.norm)

      :changed
    end

    # A word only counts as moved if it's the same word on both sides, or
    # the same lemma with a case ending changed (الصابئين / الصابئون).
    # Looser matches (الذين / الذي) would claim words that didn't move.
    def self.movable?(a, b)
      kind = compare(a, b)
      %i[exact affix].include?(kind) || (kind == :form && sounds_alike?(a.norm, b.norm))
    end

    # Same length, at least 4 letters, at most 2 letters different
    def self.sounds_alike?(a, b)
      return false if a.length < 4 || a.length != b.length

      a.each_char.zip(b.each_char).count { |x, y| x != y } <= 2
    end

    # source, target: arrays of Corpus::Token. Target entries can be nil
    # (words already used by an earlier match). Returns [pairs, score] or nil.
    def align(source, target)
      rows = source.size
      cols = target.size
      return if rows.zero? || cols.zero?

      score = Array.new(rows + 1) { Array.new(cols + 1, 0.0) }
      best = [0.0, 0, 0]

      (1..rows).each do |i|
        (1..cols).each do |j|
          t = target[j - 1]
          diagonal = t ? score[i - 1][j - 1] + SCORES[self.class.compare(source[i - 1], t)] : -Float::INFINITY

          value = [0.0, diagonal, score[i - 1][j] + GAP, score[i][j - 1] + GAP].max
          score[i][j] = value
          best = [value, i, j] if value > best[0]
        end
      end

      return if best[0] <= 0

      [traceback(score, source, target, best[1], best[2]), best[0]]
    end

    # Words skipped on one side that show up elsewhere on the other side
    # are relabelled as moved. Also picks up a swapped word just past
    # either end of the match.
    def self.mark_moved(pairs, source, target)
      pairs = extend_for_swaps(trim_ends(pairs), source, target)

      loose_sources = pairs.select { |p| p.source && (p.target.nil? || p.kind == :changed) }.map(&:source)
      loose_targets = pairs.select { |p| p.target && (p.source.nil? || p.kind == :changed) }.map(&:target)

      moved_sources = []
      moved_targets = []
      loose_sources.each do |s|
        t = loose_targets.detect { |candidate| !moved_targets.include?(candidate) && movable?(s, candidate) }
        next unless t

        moved_sources << s
        moved_targets << t
      end

      pairs.flat_map do |p|
        source_moved = p.source && moved_sources.include?(p.source)
        target_moved = p.target && moved_targets.include?(p.target)
        next [p] unless source_moved || target_moved

        if p.source && p.target
          # A changed pair whose words each moved somewhere else
          [
            Pair.new(source: p.source, target: nil, kind: source_moved ? :moved : :omitted),
            Pair.new(source: nil, target: p.target, kind: target_moved ? :moved : :added)
          ]
        else
          [Pair.new(source: p.source, target: p.target, kind: :moved)]
        end
      end
    end

    # For a phrase the reviewer picked: if the match stops one word short
    # of either end of it, take the ayah's next word as a changed word.
    # e.g. "لآيات لقوم يتفكرون" / "لآيات لقوم يعقلون" keeps يعقلون.
    def self.fill_edges(pairs, source, target)
      first_s = source.index(pairs.detect(&:source)&.source)
      last_s = source.index(pairs.reverse.detect(&:source)&.source)
      first_t = target.index(pairs.detect(&:target)&.target)
      last_t = target.index(pairs.reverse.detect(&:target)&.target)
      return pairs unless first_s && first_t

      if first_s == 1
        before = first_t.positive? ? target[first_t - 1] : nil
        pairs = [edge_pair(source[0], before)] + pairs
      end

      if last_s == source.size - 2
        pairs += [edge_pair(source[-1], target[last_t + 1])]
      end

      pairs
    end

    # The ayah's word next to the match, or the phrase word marked missing
    # when the ayah has nothing there.
    def self.edge_pair(source_word, target_word)
      if target_word
        Pair.new(source: source_word, target: target_word, kind: compare(source_word, target_word))
      else
        Pair.new(source: source_word, target: nil, kind: :omitted)
      end
    end

    # Drop a loosely related word hanging off either end after a skipped
    # word, e.g. "... لهو ولعب [وان] الدار" where الدار only shares a lemma.
    def self.trim_ends(pairs)
      pairs = pairs.dup

      2.times do
        [:last, :first].each do |side|
          ends = side == :last ? pairs.reverse : pairs
          next unless ends.size > 2 && %i[form root].include?(ends[0].kind) && %i[added omitted].include?(ends[1].kind)

          drop = 1 + ends[1..].take_while { |p| %i[added omitted].include?(p.kind) }.size
          pairs = side == :last ? pairs[0...-drop] : pairs[drop..]
        end
      end

      pairs
    end

    # Local alignment stops before a swapped word at the edge of a phrase
    # (... لعب ولهو / ... لهو ولعب). Pull in up to three words past either end
    # when they match a leftover word on the other side.
    def self.extend_for_swaps(pairs, source, target)
      source_at = source.each_with_index.to_h { |t, i| [t.object_id, i] }
      target_at = target.each_with_index.select { |t, _| t }.to_h { |t, i| [t.object_id, i] }

      first_s = pairs.detect(&:source)&.then { |p| source_at[p.source.object_id] }
      last_s = pairs.reverse.detect(&:source)&.then { |p| source_at[p.source.object_id] }
      first_t = pairs.detect(&:target)&.then { |p| target_at[p.target.object_id] }
      last_t = pairs.reverse.detect(&:target)&.then { |p| target_at[p.target.object_id] }
      return pairs unless first_s && first_t

      loose_sources = pairs.select { |p| p.source && (p.target.nil? || p.kind == :changed) }.map(&:source)
      loose_targets = pairs.select { |p| p.target && (p.source.nil? || p.kind == :changed) }.map(&:target)

      after_s = source[(last_s + 1), SWAP_REACH].to_a
      after_t = target[(last_t + 1), SWAP_REACH].to_a.take_while(&:itself)
      before_s = source[[first_s - SWAP_REACH, 0].max...first_s].to_a.reverse
      before_t = target[[first_t - SWAP_REACH, 0].max...first_t].to_a.reverse.take_while(&:itself)

      tail_s = reach(after_s, loose_targets + after_t)
      tail_t = reach(after_t, loose_sources + after_s)
      head_s = reach(before_s, loose_targets + before_t).reverse
      head_t = reach(before_t, loose_sources + before_s).reverse

      head_s.map { |w| Pair.new(source: w, target: nil, kind: :omitted) } +
        head_t.map { |w| Pair.new(source: nil, target: w, kind: :added) } +
        pairs +
        tail_s.map { |w| Pair.new(source: w, target: nil, kind: :omitted) } +
        tail_t.map { |w| Pair.new(source: nil, target: w, kind: :added) }
    end

    # Words from `words` (nearest first) up to the furthest one that has a
    # strong match in `pool`.
    def self.reach(words, pool)
      last = words.rindex { |w| pool.any? { |other| movable?(w, other) } }
      last ? words[0..last] : []
    end

    protected

    def traceback(score, source, target, i, j)
      pairs = []

      while i.positive? && j.positive? && score[i][j].positive?
        t = target[j - 1]
        kind = t && self.class.compare(source[i - 1], t)

        if t && score[i][j] == score[i - 1][j - 1] + SCORES[kind]
          pairs.unshift(Pair.new(source: source[i - 1], target: t, kind: kind))
          i -= 1
          j -= 1
        elsif score[i][j] == score[i - 1][j] + GAP
          pairs.unshift(Pair.new(source: source[i - 1], target: nil, kind: :omitted))
          i -= 1
        else
          pairs.unshift(Pair.new(source: nil, target: t, kind: :added)) if t
          j -= 1
        end
      end

      pairs
    end
  end
end
