module Search
  module ArabicNormalizer
    MARK_RANGES = [
      "ً-ٟ",
      "ٰ",
      "ۖ-ۭ",
      "ـ",
      "​-‏",
      "﻿",
      "­"
    ].freeze

    SPACE_CLASS = "  -   　".freeze

    SQL_MARKS_CLASS = MARK_RANGES.join.freeze
    MARKS_PATTERN = /[#{SQL_MARKS_CLASS}]/.freeze
    SPACE_PATTERN = /[#{SPACE_CLASS}]/.freeze

    # Letters that should be folded together before matching. Urdu, Farsi and
    # Pashto keyboards produce their own code points for letters that look the
    # same as the Arabic ones used by the mushaf, so a query typed on any of
    # them has to reach the Arabic spelling.
    TRANSLATIONS = {
      "أ" => "ا", "إ" => "ا", "آ" => "ا", "ٱ" => "ا",
      "ى" => "ي", "ة" => "ه", "ؤ" => "و", "ئ" => "ي",
      "ک" => "ك",
      "ی" => "ي", "ے" => "ي", "ې" => "ي", "ۍ" => "ي",
      "ہ" => "ه", "ھ" => "ه", "ۃ" => "ه", "ۀ" => "ه", "ۂ" => "ه"
    }.freeze

    # Derived from the map so the two sides cannot drift apart. Postgres
    # translate() pairs them by position, and so does translate_char.
    TRANSLATE_FROM = TRANSLATIONS.keys.join.freeze
    TRANSLATE_TO   = TRANSLATIONS.values.join.freeze

    module_function

    def normalize(str)
      return '' if str.nil?

      result = +''
      str.each_char do |ch|
        next if MARKS_PATTERN.match?(ch)

        result << map_char(ch)
      end

      result.downcase
    end

    def normalize_with_map(str)
      normalized = +''
      map = []
      return [normalized, map] if str.nil?

      str.each_char.with_index do |ch, index|
        if MARKS_PATTERN.match?(ch)
          map.last[1] = index + 1 unless map.empty?
          next
        end

        normalized << map_char(ch)
        map << [index, index + 1]
      end

      [normalized.downcase, map]
    end

    def sql_normalize(column)
      stripped = "regexp_replace(lower(#{column}), '[#{SQL_MARKS_CLASS}]', '', 'g')"
      spaced = "regexp_replace(#{stripped}, '[#{SPACE_CLASS}]', ' ', 'g')"
      "translate(#{spaced}, '#{TRANSLATE_FROM}', '#{TRANSLATE_TO}')"
    end

    def map_char(char)
      SPACE_PATTERN.match?(char) ? ' ' : translate_char(char)
    end

    def translate_char(char)
      TRANSLATIONS.fetch(char, char)
    end
  end
end
