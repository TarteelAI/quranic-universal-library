module Mutashabihat
  # A phrase found by auto-detect: a span of words in the ayah being
  # reviewed, and the other ayahs that share it.
  class Suggestion
    MIN_OVERLAP = 0.5
    # Phrases like يا أيها الذين آمنوا appear in this many ayahs or more
    COMMON_IN = 25

    attr_reader :verse, :from, :to, :matches

    # Matches whose spans in the source ayah mostly overlap describe the
    # same phrase, so they're grouped into one suggestion. Each group is
    # named after its most common span.
    def self.group(verse, matches)
      groups = []

      matches
        .group_by(&:source_range)
        .sort_by { |range, list| [-list.size, range[0] - range[1]] }
        .each do |range, list|
          group = groups.detect { |g| overlap(g[:range], range) >= MIN_OVERLAP }
          group ? group[:matches].concat(list) : groups << { range: range, matches: list }
        end

      groups
        .map { |g| new(verse, g[:range], g[:matches]) }
        .sort_by { |s| [s.from, -s.words_count] }
    end

    def self.overlap(a, b)
      shared = [a[1], b[1]].min - [a[0], b[0]].max + 1
      return 0.0 if shared <= 0

      shared.to_f / ([a[1], b[1]].max - [a[0], b[0]].min + 1)
    end

    def initialize(verse, range, matches)
      @verse = verse
      @from, @to = range
      @matches = matches.sort_by { |m| [m.exact? ? 0 : 1, -m.score] }
    end

    def common?
      verses_count >= COMMON_IN
    end

    def words_count
      to - from + 1
    end

    def verses_count
      matches.map(&:verse_id).uniq.size
    end

    def exact_count
      matches.count(&:exact?)
    end

    def similar_count
      matches.size - exact_count
    end

    def words
      verse.words.select { |w| w.position.between?(from, to) && !w.ayah_mark? }
    end

    def text
      words.map(&:text_qpc_hafs).join(' ')
    end

    # Saved rows in this ayah covering about the same words
    def saved_phrase_verses
      @saved_phrase_verses ||= verse.phrase_verses.includes(:phrase).select do |pv|
        pv.phrase && pv.word_position_from && pv.word_position_to &&
          self.class.overlap([pv.word_position_from, pv.word_position_to], [from, to]) >= 0.6
      end
    end

    # Saved phrase in this ayah covering about the same words, if any.
    # A row a reviewer removed doesn't count as saved.
    def saved_phrase_verse
      saved_phrase_verses.detect { |pv| pv.review_status != 'remove' }
    end

    # Matches in ayahs the saved phrases don't have yet. Ayahs a reviewer
    # removed from them count as known, they were already rejected.
    def new_matches
      @new_matches ||= begin
        phrase_ids = saved_phrase_verses.map(&:phrase_id).uniq
        known = Morphology::PhraseVerse.where(phrase_id: phrase_ids).pluck(:verse_id).to_set
        matches.reject { |m| known.include?(m.verse_id) }
      end
    end

    # Nothing to add: the phrase is saved with every ayah found
    def already_saved?
      saved_phrase_verses.any? && new_matches.empty?
    end
  end
end
