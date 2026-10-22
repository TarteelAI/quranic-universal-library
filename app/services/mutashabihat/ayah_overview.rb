module Mutashabihat
  # Saved phrases of ayahs, for the proofreading pages: counts for the ayah
  # list, and the phrases of one ayah grouped for its detail page.
  #
  # Rows a reviewer removed (review_status 'remove') are left out everywhere.
  class AyahOverview
    Stats = Struct.new(:phrases_count, :reviewed_count, :pending_count, :not_approved_count,
                       :linked_ayahs_count, :covered_words, :words_count, keyword_init: true) do
      def status
        return :none if phrases_count.zero?

        pending_count.positive? ? :needs_review : :reviewed
      end
    end

    # One phrase found in the ayah. rows are this ayah's ranges of it
    # (a phrase can occur more than once in an ayah).
    # Some old rows end on the ayah number marker, max_position clamps them.
    Group = Struct.new(:phrase, :rows, :ayahs_count, :index, :max_position, keyword_init: true) do
      def color
        phrase.get_color
      end

      def ranges
        rows.select(&:word_position_from).map { |r| [r.word_position_from, [r.word_position_to, max_position].min] }.uniq
      end

      def approved?
        phrase.approved? && rows.any?(&:approved?)
      end

      def pending?
        !phrase.reviewed? || rows.any? { |r| r.review_status.nil? }
      end

      def covers?(position)
        rows.any? { |r| r.word_position_from && position.between?(r.word_position_from, r.word_position_to) }
      end

      def first_position
        rows.map(&:word_position_from).compact.min || 0
      end
    end

    STATUS_FILTERS = {
      'with_phrases' => 'Has phrases',
      'needs_review' => 'Needs review',
      'reviewed' => 'All reviewed',
      'without_phrases' => 'No phrases'
    }.freeze

    # Verse ids for a status filter, nil when the filter doesn't narrow the list
    def self.verse_ids_for(status)
      rows = Morphology::PhraseVerse.not_removed
      pending = rows.joins(:phrase).where("morphology_phrase_verses.review_status IS NULL OR morphology_phrases.review_status IS DISTINCT FROM 'new'")

      case status
      when 'with_phrases', 'without_phrases' then rows.distinct.pluck(:verse_id)
      when 'needs_review' then pending.distinct.pluck(:verse_id)
      when 'reviewed' then rows.distinct.pluck(:verse_id) - pending.distinct.pluck(:verse_id)
      end
    end

    # verse_id => Stats for the given verses
    def self.stats_for(verses)
      verse_ids = verses.map(&:id)
      rows = Morphology::PhraseVerse.not_removed.where(verse_id: verse_ids)
                                    .pluck(:verse_id, :phrase_id, :approved, :review_status, :word_position_from, :word_position_to)
      phrase_ids = rows.map(&:second).uniq
      reviewed = Morphology::Phrase.where(id: phrase_ids, review_status: 'new').pluck(:id).to_set

      ayahs_by_phrase = Hash.new { |h, k| h[k] = Set.new }
      Morphology::PhraseVerse.not_removed.where(phrase_id: phrase_ids).pluck(:phrase_id, :verse_id).each do |phrase_id, verse_id|
        ayahs_by_phrase[phrase_id] << verse_id
      end

      by_verse = rows.group_by(&:first)

      verses.to_h do |verse|
        list = by_verse[verse.id].to_a
        phrases = list.map(&:second).uniq
        pending = phrases.count { |id| !reviewed.include?(id) || list.any? { |r| r[1] == id && r[3].nil? } }
        covered = list.flat_map { |r| r[4] && r[5] ? (r[4]..[r[5], verse.words_count.to_i].min).to_a : [] }.uniq.size

        [verse.id, Stats.new(
          phrases_count: phrases.size,
          reviewed_count: phrases.size - pending,
          pending_count: pending,
          not_approved_count: list.reject { |r| r[2] }.map(&:second).uniq.size,
          linked_ayahs_count: (phrases.flat_map { |id| ayahs_by_phrase[id].to_a }.uniq - [verse.id]).size,
          covered_words: covered,
          words_count: verse.words_count.to_i
        )]
      end
    end

    attr_reader :verse

    def initialize(verse)
      @verse = verse
    end

    def words
      @words ||= verse.words.reject(&:ayah_mark?).sort_by(&:position)
    end

    def ayah_mark
      verse.words.detect(&:ayah_mark?)
    end

    # Phrases in reading order of where they start in the ayah
    def groups
      @groups ||= begin
        rows = verse.verse_phrases.not_removed.to_a.select(&:phrase)
        counts = Morphology::PhraseVerse.not_removed.where(phrase_id: rows.map(&:phrase_id).uniq)
                                        .group(:phrase_id).distinct.count(:verse_id)

        rows.group_by(&:phrase)
            .map { |phrase, list| Group.new(phrase: phrase, rows: list, ayahs_count: counts[phrase.id].to_i, max_position: words.last&.position.to_i) }
            .sort_by { |g| [g.first_position, -g.ranges.sum { |f, t| t.to_i - f.to_i }] }
            .each_with_index { |g, i| g.index = i + 1 }
      end
    end

    def groups_at(position)
      groups.select { |g| g.covers?(position) }
    end

    def source_keys
      @source_keys ||= Verse.where(id: groups.map { |g| g.phrase.source_verse_id }.compact.uniq).pluck(:id, :verse_key).to_h
    end

    def source_label(phrase)
      key = source_keys[phrase.source_verse_id]
      return unless key

      phrase.word_position_from ? "#{key} (words #{phrase.word_position_from}–#{phrase.word_position_to})" : key
    end
  end
end
