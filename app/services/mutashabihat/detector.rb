module Mutashabihat
  # Finds mutashabihat: phrases of 3 or more words shared by more than one
  # ayah, either word for word or with small differences (see Aligner for
  # the kinds of difference). An ayah of only 2 words counts as a phrase
  # when all of it is shared (1:3 الرحمن الرحيم).
  #
  #   detector = Mutashabihat::Detector.new
  #   detector.matches_for(verse, 1, 4)  # ayahs that share words 1-4 of verse
  #   detector.auto_detect(verse)        # every shared phrase in verse
  #
  # Nothing here writes to the database. Results are suggestions until a
  # reviewer approves them in the phrase builder.
  class Detector
    MIN_WORDS = 3
    # Of the shared words, at least this many must be more than particles
    MIN_CONTENT_WORDS = 2
    # Searching for a picked phrase, a match must share this much of it
    MIN_COVERAGE = 0.4
    # Alignment score a match needs (see Aligner::SCORES). Three exact words
    # score 12, while a few words with the same lemma between changed and
    # skipped words fall short.
    MIN_SCORE = 10
    # A phrase the reviewer picked gets a lower bar, they review every result
    MIN_SCORE_FOR_PHRASE = 8
    # Sharing a rare word (Corpus#rare?) is enough content, and the match
    # may have one gap or changed form: الذين أنعمت عليهم / الذين أنعم الله عليهم
    MIN_SCORE_WITH_RARE_WORD = 9
    MAX_MATCHES_PER_AYAH = 3

    attr_reader :corpus

    def initialize(corpus = Corpus.instance)
      @corpus = corpus
      @aligner = Aligner.new
    end

    # Ayahs containing the phrase at words from..to of the verse, best first.
    # The source ayah itself is included, along with any other place in it
    # where the phrase repeats.
    def matches_for(verse, from, to, limit: 300)
      source = corpus.tokens_in_range(verse.id, from, to)
      # Fewer words only when they are the whole (short) ayah
      return [] if source.size < 2 || (source.size < MIN_WORDS && source.size < corpus.tokens(verse.id).size)

      needed = [MIN_WORDS, (source.size * MIN_COVERAGE).ceil].max
      # Picked phrases are often mostly particles: أولئك هم الخاسرون
      content = 1
      own = Match.new(verse_id: verse.id, verse_key: verse.verse_key, pairs: source.map { |t| Aligner::Pair.new(source: t, target: t, kind: :exact) })

      others = candidates(source, exclude: verse.id).flat_map do |verse_id|
        matches_in(source, verse_id, needed, content: content, min_score: MIN_SCORE_FOR_PHRASE, fill_edges: true)
      end
      repeats = matches_in(source, verse.id, needed, content: content, min_score: MIN_SCORE_FOR_PHRASE, skip: source, fill_edges: true)

      [own] + (repeats + others).sort_by { |m| [-m.score, m.verse_id] }.first(limit)
    end

    # Shared phrases in a whole ayah, grouped by where they sit in it.
    def auto_detect(verse)
      source = corpus.tokens(verse.id)

      matches = candidates(source, exclude: verse.id, min_shared: 2).flat_map do |verse_id|
        matches_in(source, verse_id, MIN_WORDS)
      end

      Suggestion.group(verse, matches)
    end

    # Best match in one specific ayah, however weak. Used when a reviewer
    # adds an ayah by hand, to preselect the words.
    def match_in(verse, from, to, other_verse)
      source = corpus.tokens_in_range(verse.id, from, to)
      matches_in(source, other_verse.id, nil, fill_edges: true).first
    end

    protected

    def candidates(source, exclude:, min_shared: 1)
      min_shared = 1 if source.size <= 4
      corpus.candidate_verse_ids(source, exclude: exclude, min_shared: min_shared)
    end

    # Up to MAX_MATCHES_PER_AYAH separate matches of source in the ayah.
    # `skip` words are hidden from the ayah first (the source phrase itself
    # when looking for repeats inside its own ayah). With `needed` nil, the
    # best match is returned without any quality check.
    def matches_in(source, verse_id, needed, content: MIN_CONTENT_WORDS, min_score: MIN_SCORE, skip: [], fill_edges: false)
      target = corpus.tokens(verse_id).map { |t| skip.include?(t) ? nil : t }
      found = []

      # A short ayah on either side is matched as a whole
      shortest = [source.size, target.compact.size].min
      if needed && shortest.between?(2, MIN_WORDS - 1)
        needed = shortest
        content = 1
        min_score = shortest * Aligner::SCORES[:affix]
      end

      MAX_MATCHES_PER_AYAH.times do
        pairs, score = @aligner.align(source, target)
        break unless pairs

        pairs = Aligner.mark_moved(pairs, source, target)
        pairs = Aligner.fill_edges(pairs, source, target) if fill_edges
        match = Match.new(verse_id: verse_id, verse_key: corpus.verse_keys[verse_id], pairs: pairs, score: score)
        break unless needed.nil? || good_match?(match, needed, content, min_score)

        found << match
        break if needed.nil?

        used = pairs.filter_map(&:target)
        target = target.map { |t| t && used.include?(t) ? nil : t }
      end

      found
    end

    def good_match?(match, needed, content, min_score)
      return false if match.strong_count < needed
      return true if match.content_count >= content && match.score >= min_score

      rare_word?(match) && match.score >= [min_score, MIN_SCORE_WITH_RARE_WORD].min
    end

    def rare_word?(match)
      match.pairs.any? { |p| Aligner::STRONG.include?(p.kind) && p.source && corpus.rare?(p.source) }
    end
  end
end
