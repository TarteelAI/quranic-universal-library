module Mutashabihat
  # How an ayah's range of a saved phrase differs from the phrase, for
  # colouring words on the ayah proofreading page.
  #
  #   added    the ayah has a word the phrase doesn't (هو in 2:163)
  #   changed  the ayah has a different word in the same place
  #   omitted  the phrase has a word the ayah doesn't, shown as a ghost word
  #
  # Other differences (prefix, word form, order) count as the same word.
  class PhraseDiff
    Result = Struct.new(:kinds, :omitted, :changed_from, keyword_init: true) do
      # :added, :changed or nil for a word of the ayah
      def kind_at(position)
        kinds[position]
      end

      # Phrase words missing just before this ayah word, nil for after the range
      def omitted_before(position)
        omitted[position].to_a
      end

      def any?
        kinds.any? || omitted.any?
      end
    end

    def initialize(phrase_words)
      @source = tokens(phrase_words)
      @source_words = phrase_words.index_by(&:position)
    end

    # words: Word records of the ayah's range
    def compare(words)
      empty = Result.new(kinds: {}, omitted: {}, changed_from: {})
      target = tokens(words)
      return empty if @source.empty? || target.empty?

      pairs, = Aligner.new.align(@source, target)
      return empty unless pairs

      pairs = Aligner.mark_moved(pairs, @source, target)
      pairs = Aligner.fill_edges(pairs, @source, target)
      result(pairs, target)
    end

    protected

    def result(pairs, target)
      kinds = {}
      omitted = Hash.new { |h, k| h[k] = [] }
      changed_from = {}
      paired_sources = pairs.filter_map(&:source)
      paired_targets = pairs.filter_map(&:target)

      # Phrase words the alignment left off either end are missing too
      first_paired = @source.index(paired_sources.first) || @source.size
      last_paired = @source.index(paired_sources.last) || -1
      pending = @source[0...first_paired].to_a

      pairs.each do |pair|
        if pair.target
          omitted[pair.target.position].concat(pending.map { |t| word_text(t) }) if pending.any?
          pending = []

          if pair.kind == :added
            kinds[pair.target.position] = :added
          elsif pair.kind == :changed
            kinds[pair.target.position] = :changed
            changed_from[pair.target.position] = word_text(pair.source)
          end
        elsif pair.kind == :omitted
          pending << pair.source
        end
      end

      pending += @source[(last_paired + 1)..].to_a
      omitted[nil].concat(pending.map { |t| word_text(t) }) if pending.any?

      # Ayah words in the range the alignment didn't reach
      (target - paired_targets).each { |t| kinds[t.position] = :added }

      Result.new(kinds: kinds, omitted: omitted.to_h, changed_from: changed_from)
    end

    def word_text(token)
      @source_words[token.position]&.text_qpc_hafs || token.text
    end

    def tokens(words)
      words.reject(&:ayah_mark?).sort_by(&:position).map do |word|
        norm = Corpus.normalize(word.text_imlaei_simple)

        Corpus::Token.new(
          verse_id: word.verse_id,
          position: word.position,
          text: word.text_imlaei_simple,
          norm: norm,
          bare: Corpus.strip_conjunction(norm),
          stem_id: word.stem_id,
          lemma_id: word.lemma_id,
          root_id: word.root_id
        )
      end
    end
  end
end
