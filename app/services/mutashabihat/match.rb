module Mutashabihat
  # One place where a phrase was found: the words in the source phrase and
  # the ayah lined up pair by pair, each with how it differs.
  class Match
    KIND_LABELS = {
      exact: 'Exact',
      affix: 'Prefix/suffix',
      form: 'Word form',
      root: 'Same root',
      similar: 'Sounds similar',
      changed: 'Word changed',
      moved: 'Order changed',
      omitted: 'Word missing',
      added: 'Word added'
    }.freeze

    attr_reader :verse_id, :verse_key, :pairs, :score

    def initialize(verse_id:, verse_key:, pairs:, score: nil)
      @verse_id = verse_id
      @verse_key = verse_key
      @pairs = pairs
      @score = score || pairs.size * Aligner::SCORES[:exact]
    end

    def strong_count
      pairs.count { |p| Aligner::STRONG.include?(p.kind) && p.source }
    end

    # Shared words with a root, so not just particles like من، على، الذين
    def content_count
      pairs.count { |p| Aligner::STRONG.include?(p.kind) && p.source&.root_id }
    end

    def source_range
      positions = pairs.filter_map { |p| p.source&.position }
      [positions.min, positions.max]
    end

    def target_range
      positions = pairs.filter_map { |p| p.target&.position }
      [positions.min, positions.max]
    end

    def exact?
      pairs.all? { |p| p.kind == :exact }
    end

    # Differences found, in a stable order. Empty when exact.
    def kinds
      found = pairs.map(&:kind).uniq
      (KIND_LABELS.keys & found) - [:exact]
    end

    def kind_labels
      exact? ? [KIND_LABELS[:exact]] : kinds.map { |k| KIND_LABELS[k] }
    end

    # Target word positions that differ from the source, position => kind.
    # Used to colour words in the builder.
    def target_word_kinds
      pairs.each_with_object({}) do |p, kinds|
        kinds[p.target.position] = p.kind if p.target && p.kind != :exact
      end
    end

    # Target positions inside the range that aren't part of the phrase
    def excluded_positions
      pairs.filter_map { |p| p.target.position if p.target && p.kind == :added }
    end
  end
end
