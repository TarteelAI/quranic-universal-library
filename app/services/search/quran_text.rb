module Search
  class QuranText
    SEARCH_COLUMNS = %w[
      text_uthmani
      text_uthmani_simple
      text_imlaei
      text_imlaei_simple
      text_indopak
      text_indopak_nastaleeq
      text_qpc_hafs
      text_qpc_nastaleeq
      text_qpc_nastaleeq_hafs
      text_digital_khatt
      text_digital_khatt_v1
      text_digital_khatt_indopak
    ].freeze

    MIN_QUERY_LENGTH = 2
    AYAH_KEY_PATTERN = /\A(\d{1,3})[\s:،,\-]+(\d{1,3})\z/

    def initialize(query:, exact: false, across: false, index: nil)
      @raw = query.to_s.strip
      @exact = exact
      @across = across
      @index = index
    end

    def across?
      @across
    end

    def pattern
      @pattern ||= Pattern.new(@raw, exact: @exact)
    end

    def ayah_key
      match = AYAH_KEY_PATTERN.match(@raw)
      return nil unless match

      "#{match[1].to_i}:#{match[2].to_i}"
    end

    def ayah_key?
      !ayah_key.nil?
    end

    def ordered
      relation.order(:verse_index)
    end

    def relation
      return Verse.where(verse_key: ayah_key) if ayah_key?
      return Verse.where(id: index.verse_ids(@raw)) if @across
      return Verse.none if pattern.blank?

      operator = pattern.word_gap? ? '~*' : 'ILIKE'
      query = pattern.word_gap? ? pattern.sql_regex : pattern.like
      clause = SEARCH_COLUMNS.map { |column| "#{column_expression(column)} #{operator} :q" }.join(' OR ')
      Verse.where(clause, q: query)
    end

    def matched_columns(verse)
      return [] if @across || ayah_key? || pattern.blank?

      regexp = pattern.match_regexp
      SEARCH_COLUMNS.select { |column| matches?(regexp, verse.read_attribute(column)) }
    end

    private

    def index
      @index ||= QuranIndex.instance
    end

    def matches?(regexp, value)
      return false if value.nil?

      haystack = @exact ? value.to_s : ArabicNormalizer.normalize(value.to_s)
      regexp.match?(haystack)
    end

    def column_expression(column)
      @exact ? column : ArabicNormalizer.sql_normalize(column)
    end
  end
end
