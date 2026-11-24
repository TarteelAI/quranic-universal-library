# frozen_string_literal: true

module QuranQuote
  # Every Quran word in mushaf order, with the spellings a tafsir might quote
  # it in (Uthmani, Imlaei, IndoPak...). Finds where a run of Arabic words
  # comes from, down to the word, even when the quote crosses ayahs.
  #
  # Ayah end markers aren't in the index, so ayah numbers in a quote are
  # skipped and a quote of several ayahs matches as one run.
  class WordIndex
    COLUMNS = %w[
      text_qpc_hafs
      text_uthmani
      text_uthmani_simple
      text_imlaei
      text_imlaei_simple
      text_indopak
    ].freeze

    # A run of Arabic letters with the marks on them. Harakat are in the
    # Inherited script, not Arabic, so any combining mark counts.
    WORD_PATTERN = /(?:[\p{L}&&\p{Arabic}]|\p{M})+/

    # tokens[token_start..token_end] is the Quran from word_start to word_end
    Match = Struct.new(:token_start, :token_end, :word_start, :word_end) do
      def size
        word_end - word_start + 1
      end
    end

    def self.instance
      @instance ||= from_words
    end

    def self.reset!
      @instance = nil
    end

    def self.from_words
      rows = ::Word.unscoped
                   .where(char_type_name: 'word')
                   .joins(:verse)
                   .order('verses.verse_index, words.position')
                   .pluck(:location, :verse_id, *COLUMNS.map { |column| "words.#{column}" })

      new(rows.map { |location, verse_id, *texts| [location, verse_id, texts] })
    end

    # Normalized words of a text, each with where it sits in the text:
    # [[word, start, end], ...]
    def self.tokenize(text)
      tokens = []
      text.to_s.scan(WORD_PATTERN) do
        match = Regexp.last_match
        word = normalize(match[0])
        tokens << [word, match.begin(0), match.end(0)] if word.present?
      end
      tokens
    end

    def self.normalize(word)
      Search::ArabicNormalizer.normalize(word).gsub(/\p{M}/, '')
    end

    # words: [[location, verse_id, [spellings]], ...] in mushaf order
    def initialize(words)
      @locations = []
      @verse_ids = []
      @forms = []
      @starts = Hash.new { |hash, key| hash[key] = [] }

      words.each_with_index do |(location, verse_id, texts), index|
        # A spelling can be more than one word, e.g. Imlaei "يا أيها"
        forms = texts.map { |text| self.class.tokenize(text).map(&:first) }
                     .reject(&:empty?)
                     .uniq
                     .sort_by { |form| -form.size }

        @locations << location
        @verse_ids << verse_id
        @forms << forms
        forms.map(&:first).uniq.each { |first| @starts[first] << index }
      end

      @starts.default_proc = nil
    end

    def location(word_index)
      @locations[word_index]
    end

    def verse_id(word_index)
      @verse_ids[word_index]
    end

    # Every place in the Quran the words from tokens[from] onwards match,
    # each as long as it goes.
    def matches_at(tokens, from)
      @starts.fetch(tokens[from], []).map do |word_start|
        token = from
        word = word_start

        while word < @forms.size && (form = @forms[word].find { |f| tokens[token, f.size] == f })
          token += form.size
          word += 1
        end

        Match.new(from, token - 1, word_start, word - 1)
      end.select { |match| match.size.positive? }
    end
  end
end
