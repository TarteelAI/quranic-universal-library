module Mutashabihat
  # Everything the phrase builder shows: the source phrase, and one card per
  # ayah that shares it, combining what's already saved with what the
  # detector suggests.
  class PhraseReview
    # status: :saved (has saved rows for this phrase) or :suggested
    # matched: the detector found the phrase in this ayah (kinds are known)
    # suggested_ranges: the detector's ranges when they differ from saved ones
    Card = Struct.new(:verse, :ranges, :excluded, :word_kinds, :kinds, :matched, :suggested_ranges, :status, :source, :phrase_verse_id, :approved, keyword_init: true) do
      def saved?
        status == :saved
      end

      # Used by the filter buttons, a saved card is also exact or similar
      def categories
        [('saved' if saved?), (kinds.empty? ? 'exact' : 'similar' if matched)].compact
      end

      def labels
        return [] if source || !matched
        return [Match::KIND_LABELS[:exact]] if kinds.empty?

        kinds.map { |k| Match::KIND_LABELS[k] }
      end
    end

    attr_reader :verse, :from, :to, :phrase

    def self.for_phrase(phrase)
      return unless phrase.source_verse && phrase.word_position_from && phrase.word_position_to

      new(phrase.source_verse, phrase.word_position_from, phrase.word_position_to, phrase: phrase)
    end

    # From builder params: an ayah key with optional word range, or a typed
    # phrase that is looked up in the Quran.
    def self.for_params(ayah_key: nil, word_from: nil, word_to: nil, text: nil)
      if ayah_key.present?
        verse = Verse.find_by(verse_key: ayah_key)
        return unless verse

        from = (word_from.presence || 1).to_i
        to = (word_to.presence || verse.words_count).to_i
      elsif text.present?
        verse_id, from, to = Corpus.instance.locate(text)
        return unless verse_id

        verse = Verse.find(verse_id)
      else
        return
      end

      new(verse, *[from, to].minmax)
    end

    def initialize(verse, from, to, phrase: nil, detector: Detector.new)
      @verse = verse
      @from = from
      @to = to
      @detector = detector
      @phrase = phrase || find_phrase
    end

    def words
      @words ||= verse.words.reject(&:ayah_mark?).sort_by(&:position)
    end

    def phrase_text
      words.select { |w| w.position.between?(from, to) }.map(&:text_qpc_hafs).join(' ')
    end

    def cards
      @cards ||= build_cards
    end

    def counts
      cards.flat_map(&:categories).tally.merge('all' => cards.size)
    end

    # Card for an ayah right after the reviewer approved it
    def self.saved_card(verse, rows, phrase)
      Card.new(
        verse: verse,
        ranges: rows.map { |r| [r.word_position_from, r.word_position_to] },
        excluded: rows.flat_map(&:missing_word_positions).uniq,
        word_kinds: {},
        kinds: [],
        status: :saved,
        source: phrase.source_verse_id == verse.id,
        phrase_verse_id: rows.first&.id,
        approved: rows.all?(&:approved?)
      )
    end

    # Card for an ayah the reviewer added by hand
    def card_for(other_verse)
      match = @detector.match_in(verse, from, to, other_verse)

      Card.new(
        verse: other_verse,
        ranges: match ? [match.target_range] : [],
        excluded: match ? match.excluded_positions : [],
        word_kinds: match ? match.target_word_kinds : {},
        kinds: match ? match.kinds : [],
        matched: match.present?,
        status: :suggested,
        source: false
      )
    end

    protected

    def find_phrase
      text = phrase_text
      Morphology::Phrase.where(source_verse_id: verse.id, word_position_from: from, word_position_to: to).first ||
        Morphology::Phrase.where('text_qpc_hafs_simple = :simple OR text_qpc_hafs = :text', simple: text.remove_diacritics, text: text).first
    end

    def build_cards
      saved = saved_rows.group_by(&:verse_id)
      matches = @detector.matches_for(verse, from, to).group_by(&:verse_id)
      verse_ids = ([verse.id] + saved.keys + matches.keys).uniq
      verses = Verse.where(id: verse_ids).includes(:words).index_by(&:id)

      cards = verse_ids.filter_map do |id|
        next unless verses[id]

        build_card(verses[id], saved[id], matches[id] || [])
      end

      best_score = matches.transform_values { |list| list.map(&:score).max }
      cards.sort_by.with_index do |card, index|
        [card.source ? 0 : 1, card.saved? ? 0 : 1, card.kinds.empty? ? 0 : 1, -(best_score[card.verse.id] || 0), index]
      end
    end

    def build_card(card_verse, rows, matches)
      word_kinds = matches.map(&:target_word_kinds).reduce({}, :merge)
      kinds = matches.flat_map(&:kinds).uniq

      if rows.present?
        saved_ranges = rows.map { |r| [r.word_position_from, r.word_position_to] }
        found_ranges = matches.map(&:target_range)

        Card.new(
          verse: card_verse,
          ranges: saved_ranges,
          suggested_ranges: found_ranges.any? && found_ranges.sort != saved_ranges.sort ? found_ranges : nil,
          excluded: rows.flat_map(&:missing_word_positions).uniq,
          word_kinds: word_kinds,
          kinds: kinds,
          matched: matches.any?,
          status: :saved,
          source: card_verse.id == verse.id,
          phrase_verse_id: rows.first.id,
          approved: rows.all?(&:approved?)
        )
      else
        Card.new(
          verse: card_verse,
          ranges: matches.map(&:target_range),
          excluded: matches.flat_map(&:excluded_positions).uniq,
          word_kinds: word_kinds,
          kinds: kinds,
          matched: true,
          status: :suggested,
          source: card_verse.id == verse.id
        )
      end
    end

    def saved_rows
      return [] unless phrase&.persisted?

      phrase.phrase_verses.not_removed.where.not(word_position_from: nil).where.not(word_position_to: nil).order(:id).to_a
    end
  end
end
