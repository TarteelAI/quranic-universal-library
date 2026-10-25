module Mutashabihat
  # Saved phrases that duplicate each other: they share most of their ayahs,
  # cover about the same words in each, and are about the same length.
  # Nested phrases are not duplicates: السماوات والأرض (130 ayahs) and
  # خلق السماوات والأرض (28) and وهو الذي خلق السماوات والأرض (3) stay apart.
  #
  #   DuplicatePhrases.new.groups                       # whole database
  #   DuplicatePhrases.new(phrase_ids: [6329, 15770]).groups
  #
  # Each group is a list of phrase ids, the one to keep first: reviewed
  # before auto-detected, then the one with most ayahs, then the oldest.
  class DuplicatePhrases
    # Word ranges in one ayah must overlap this much
    MIN_OVERLAP = 0.8
    # and this share of the larger phrase's ayahs must match
    MIN_SHARED = 0.8
    # A 4 word phrase isn't a duplicate of a 5 word one... unless 4/5 = 0.8
    MIN_LENGTH = 0.8

    def initialize(phrase_ids: nil)
      @phrase_ids = phrase_ids
    end

    def groups
      @groups ||= clusters.map { |ids| [ids.first] + ids.drop(1).sort_by { |id| keep_order(id) } }
                          .sort_by { |ids| -ids.size }
    end

    def phrases
      @phrases ||= Morphology::Phrase.where(id: rows_by_phrase.keys).index_by(&:id)
    end

    def ayahs_count(phrase_id)
      rows_by_phrase[phrase_id].map(&:first).uniq.size
    end

    protected

    def rows
      @rows ||= begin
        scope = Morphology::PhraseVerse.not_removed.where.not(word_position_from: nil)
        scope = scope.where(phrase_id: @phrase_ids) if @phrase_ids
        scope.pluck(:phrase_id, :verse_id, :word_position_from, :word_position_to)
      end
    end

    # phrase_id => [[verse_id, from, to], ...]
    def rows_by_phrase
      @rows_by_phrase ||= rows.group_by(&:first).transform_values { |list| list.map { |_, v, f, t| [v, f, t] } }
    end

    def pairs
      by_verse = Hash.new { |h, k| h[k] = [] }
      rows.each { |phrase_id, verse_id, from, to| by_verse[verse_id] << [phrase_id, from, to] }
      found = Set.new

      rows_by_phrase.each do |phrase_id, occurrences|
        shared = Hash.new(0)
        occurrences.each do |verse_id, from, to|
          by_verse[verse_id].each do |other_id, f, t|
            next if other_id == phrase_id

            shared[other_id] += 1 if Suggestion.overlap([from, to], [f, t]) >= MIN_OVERLAP
          end
        end

        shared.each do |other_id, count|
          lengths = [words_count(phrase_id), words_count(other_id)]
          next if lengths.min.to_f / lengths.max < MIN_LENGTH

          larger = [occurrences.size, rows_by_phrase[other_id].size].max
          found << [phrase_id, other_id].sort if count >= 2 && count >= (larger * MIN_SHARED).ceil
        end
      end

      found
    end

    # Each group is a phrase to keep and the phrases that duplicate it
    # directly, so A~B and B~C don't chain A and C together
    def clusters
      linked = Hash.new { |h, k| h[k] = Set.new }
      pairs.each { |a, b| linked[a] << b; linked[b] << a }
      taken = Set.new

      linked.keys.sort_by { |id| keep_order(id) }.filter_map do |id|
        next if taken.include?(id)

        group = [id] + linked[id].reject { |other| taken.include?(other) }.to_a
        next if group.size < 2

        taken.merge(group)
        group
      end
    end

    # Most common range length of the phrase's rows. The saved text isn't
    # reliable, some phrases carry an ayah number or miss a word.
    def words_count(phrase_id)
      @words_count ||= {}
      @words_count[phrase_id] ||= rows_by_phrase[phrase_id].map { |_, f, t| t - f + 1 }.tally.max_by { |len, n| [n, len] }.first
    end

    def keep_order(id)
      phrase = phrases[id]
      [phrase&.reviewed? ? 0 : 1, -ayahs_count(id), id]
    end
  end
end
