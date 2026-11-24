# frozen_string_literal: true

module QuranQuote
  # Finds Quran quotes in tafsir HTML and wraps each in
  #
  #   <quran-text data-from="2:255:1" data-to="2:256:4">...</quran-text>
  #
  # data-from and data-to are the first and last word (surah:ayah:word). They
  # are left out when the words are in the Quran more than once and the
  # tafsir's own ayahs don't say which.
  #
  # The qpc-hafs class goes away: a span holding only a quote becomes the
  # quran-text tag, and the class is dropped everywhere else. Hadith and
  # other Arabic then use the normal Arabic font, which has the punctuation
  # (، ؛ ؟) the QPC font is missing.
  class Tagger
    TAG = 'quran-text'
    OLD_CLASS = 'qpc-hafs'
    OPEN_BRACKET = '﴿'
    CLOSE_BRACKET = '﴾'

    # How many words a quote needs before it's tagged. Arabic tafsirs repeat
    # Quran words all the time while explaining them, so plain text needs a
    # few. A quote the tafsir marks itself with ﴿ ﴾ needs fewer, and fewer
    # again when it's from the ayahs the tafsir explains. The qpc-hafs class
    # doesn't count as a mark, tafsirs put it on hadith too.
    MIN_WORDS = {
      [true, true] => 1,   # marked, from the tafsir's ayahs
      [true, false] => 2,  # marked
      [false, true] => 3,  # plain, from the tafsir's ayahs
      [false, false] => 4  # plain
    }.freeze

    Result = Struct.new(:from, :to, :words, :total, keyword_init: true) do
      def located?
        from.present?
      end

      def found?
        words.to_i.positive?
      end
    end

    # verse_ids: the ayahs the tafsir explains, used to pick the right place
    # when a quote is in the Quran more than once
    def initialize(verse_ids: nil, index: WordIndex.instance)
      @verse_ids = verse_ids
      @index = index
    end

    # Tags quotes in a Nokogiri fragment, in place
    def tag(fragment)
      fragment.xpath(".//text()[not(ancestor::#{TAG})]").each do |node|
        tag_text_node(node)
      end

      fragment.css(".#{OLD_CLASS}").each { |element| replace_old_class(element) }
      fragment.css(TAG).each { |quote| replace_paragraph(quote) }

      fragment
    end

    # Where a piece of text (like a selection in the editor) is in the Quran.
    # Matches from its first word, as far as it goes.
    def locate(text)
      tokens = WordIndex.tokenize(text).map(&:first)
      return Result.new(words: 0, total: 0) if tokens.empty?

      match, located = pick(@index.matches_at(tokens, 0), marked: true)
      return Result.new(words: 0, total: tokens.size) unless match

      Result.new(**location_attributes(match, located), words: match.size, total: tokens.size)
    end

    private

    def tag_text_node(node)
      text = node.text
      tokens = WordIndex.tokenize(text)
      return if tokens.empty?

      words = tokens.map(&:first)
      brackets = bracket_ranges(text)
      quotes = []
      position = 0

      while position < words.size
        candidates = @index.matches_at(words, position)
        start_char = tokens[position][1]
        in_brackets = brackets.any? { |range| range.cover?(start_char) }
        match, located = pick(candidates, marked: in_brackets)

        if match
          quotes << [match, located]
          position = match.token_end + 1
        else
          position += 1
        end
      end

      replace_with_quotes(node, text, tokens, quotes) if quotes.any?
    end

    # The longest match that has enough words, preferring the tafsir's ayahs.
    # Returns [match, located]: located is false when the same words are in
    # more than one place and nothing says which.
    def pick(candidates, marked:)
      qualifying = candidates.select { |m| m.size >= MIN_WORDS[[marked, in_range?(m)]] }
      return if qualifying.empty?

      size = qualifying.map(&:size).max
      longest = qualifying.select { |m| m.size == size }
      in_range = longest.select { |m| in_range?(m) }

      located = in_range.any? || longest.size == 1
      # Plain text that's in the Quran in several places is more likely a
      # common phrase (in a hadith, a dua...) than a quote
      return if !marked && !located

      [in_range.first || longest.first, located]
    end

    def in_range?(match)
      return false if @verse_ids.blank?

      @verse_ids.include?(@index.verse_id(match.word_start)) ||
        @verse_ids.include?(@index.verse_id(match.word_end))
    end

    def location_attributes(match, located)
      return {} unless located

      { from: @index.location(match.word_start), to: @index.location(match.word_end) }
    end

    # Character ranges inside ﴿ ﴾ in a text
    def bracket_ranges(text)
      ranges = []
      text.scan(/#{OPEN_BRACKET}[^#{CLOSE_BRACKET}]*#{CLOSE_BRACKET}?/o) do
        match = Regexp.last_match
        ranges << (match.begin(0)...match.end(0))
      end
      ranges
    end

    def replace_with_quotes(node, text, tokens, quotes)
      document = node.document
      cursor = 0

      quotes.each do |match, located|
        from = include_bracket_before(text, tokens[match.token_start][1])
        to = include_bracket_after(text, tokens[match.token_end][2])

        node.add_previous_sibling(Nokogiri::XML::Text.new(text[cursor...from], document)) if from > cursor

        element = document.create_element(TAG)
        element.content = text[from...to]
        location_attributes(match, located).each { |key, value| element["data-#{key}"] = value }
        node.add_previous_sibling(element)

        cursor = to
      end

      node.add_previous_sibling(Nokogiri::XML::Text.new(text[cursor..], document)) if cursor < text.length
      node.remove
    end

    # Keep the ﴿ ﴾ around a quote inside the tag, they're drawn by the
    # Quran font
    def include_bracket_before(text, position)
      before = text[0...position][/#{OPEN_BRACKET}\s*\z/o]
      before ? position - before.length : position
    end

    def include_bracket_after(text, position)
      # ayah numbers can sit between the last word and the bracket
      after = text[position..][/\A[\s\p{Nd}()\[\]۝]*#{CLOSE_BRACKET}/o]
      after ? position + after.length : position
    end

    # A paragraph that only holds a quote is replaced by the quote, which is
    # shown as a block on its own. The paragraph's language and font classes
    # don't apply to the quote, anything else (a colour...) moves onto it.
    PARAGRAPHS = %w[p div].freeze
    PARAGRAPH_CLASSES = ['ar', 'arabic', OLD_CLASS].freeze

    def replace_paragraph(quote)
      paragraph = quote.parent
      return unless paragraph.respond_to?(:name) && PARAGRAPHS.include?(paragraph.name)
      return unless paragraph.element_children.size == 1 && paragraph.text.strip == quote.text.strip

      classes = (quote.classes + paragraph.classes - PARAGRAPH_CLASSES).uniq
      quote['class'] = classes.join(' ') if classes.any?
      paragraph.replace(quote)
    end

    # A span that only holds a quote becomes the quote's tag. Anything else
    # just loses the class.
    def replace_old_class(element)
      quote = element.element_children.first

      if element.name == 'span' && element.element_children.size == 1 && quote.name == TAG &&
         element.text.strip == quote.text.strip
        quote.attributes.each { |name, attribute| element[name] = attribute.value }
        element.name = TAG
        quote.replace(quote.children)
      end

      classes = element.classes - [OLD_CLASS]
      classes.empty? ? element.remove_attribute('class') : element['class'] = classes.join(' ')
    end
  end
end
