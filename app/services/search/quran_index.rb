module Search
  class QuranIndex
    Entry = Struct.new(:verse_id, :verse_key, :verse_index, :texts)

    INDEX_COLUMNS = %w[
      text_qpc_hafs
      text_uthmani
      text_imlaei_simple
      text_indopak
    ].freeze

    def self.instance
      @instance ||= from_verses
    end

    def self.reset!
      @instance = nil
    end

    def self.from_verses
      scope = Verse.order(:verse_index).select(:id, :verse_key, :verse_index, *INDEX_COLUMNS)
      entries = scope.map do |verse|
        texts = INDEX_COLUMNS.each_with_object({}) { |column, hash| hash[column] = verse.read_attribute(column) }
        Entry.new(verse.id, verse.verse_key, verse.verse_index, texts)
      end

      new(entries, columns: INDEX_COLUMNS)
    end

    def initialize(entries, columns:)
      @entries = entries
      @columns = columns
      build
    end

    def verse_ids(query)
      normalized = ArabicNormalizer.normalize(query.to_s)
      normalized = normalized.strip
      return [] if normalized.empty?

      matched = {}
      @scripts.each { |script| collect(script, normalized, matched) }

      matched.values.sort_by(&:verse_index).map(&:verse_id)
    end

    private

    def build
      @scripts = @columns.map do |column|
        joined = +''
        starts = []
        ends = []

        @entries.each do |entry|
          starts << joined.length
          joined << ArabicNormalizer.normalize(entry.texts[column].to_s)
          ends << joined.length
          joined << ' '
        end

        { joined: joined, starts: starts, ends: ends }
      end
    end

    def collect(script, normalized, matched)
      joined = script[:joined]
      starts = script[:starts]
      ends = script[:ends]

      cursor = 0
      while (index = joined.index(normalized, cursor))
        match_end = index + normalized.length
        mark_overlapping(starts, ends, index, match_end, matched)
        cursor = index + 1
      end
    end

    def mark_overlapping(starts, ends, match_start, match_end, matched)
      first = ends.bsearch_index { |value| value > match_start }
      return if first.nil?

      position = first
      while position < @entries.length && starts[position] < match_end
        entry = @entries[position]
        matched[entry.verse_id] = entry
        position += 1
      end
    end
  end
end
