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
  #
  # A quote can run through inline markup (a highlighted word, bold...), the
  # markup is split where the quote starts and ends.
  class Tagger
    TAG = 'quran-text'
    OLD_CLASS = 'qpc-hafs'
    OPEN_BRACKET = '﴿'
    CLOSE_BRACKET = '﴾'
    # Brackets tafsirs put around a quote. Only ﴿ ﴾ go inside the tag, the
    # Quran font draws them.
    BRACKETS = [[OPEN_BRACKET, CLOSE_BRACKET], ['{', '}']].freeze

    # Markup a quote can run through. Anything else (p, div, br, li...) ends
    # the text a quote is looked for in.
    INLINE_ELEMENTS = %w[span b strong i em u a sup sub small mark del ins font abbr].freeze

    # How many words a quote needs before it's tagged. Arabic tafsirs repeat
    # Quran words all the time while explaining them, so plain text needs a
    # few. A quote the tafsir marks itself with ﴿ ﴾ or { } needs fewer, and fewer
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
      text_runs(fragment).each { |nodes| tag_run(nodes) }

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

    # The text nodes of a fragment, grouped into runs of text a quote can
    # span: a paragraph's text, through its inline markup. Existing quotes
    # are skipped.
    def text_runs(root)
      runs = [[]]
      walk = lambda do |node|
        node.children.each do |child|
          if child.text?
            runs.last << child
          elsif child.element? && INLINE_ELEMENTS.include?(child.name)
            walk.call(child)
          elsif child.element?
            runs << []
            walk.call(child) unless child.name == TAG
            runs << []
          end
        end
      end

      walk.call(root)
      runs.reject(&:empty?)
    end

    def tag_run(nodes)
      text = +''
      starts = nodes.map { |node| text.length.tap { text << node.text } }
      tokens = WordIndex.tokenize(text)
      return if tokens.empty?

      brackets = bracket_ranges(text)
      quotes = []

      segments(text, tokens).each do |first, last|
        words = tokens[first..last].map(&:first)
        position = 0

        while position < words.size
          candidates = @index.matches_at(words, position)
          in_brackets = brackets.any? { |range| range.cover?(tokens[first + position][1]) }
          match, located = pick(candidates, marked: in_brackets)

          if match
            quotes << [shift(match, first), located]
            position = match.token_end + 1
          else
            position += 1
          end
        end
      end

      # From the last quote back, so splitting the text for one quote doesn't
      # move the text of the quotes before it
      quotes.reverse_each do |match, located|
        from = include_bracket_before(text, tokens[match.token_start][1])
        to = include_bracket_after(text, tokens[match.token_end][2])

        wrap(*node_at(nodes, starts, from, ending: false), *node_at(nodes, starts, to, ending: true),
             location_attributes(match, located))
      end
    end

    # A quote can't run past words in another language (only Arabic words
    # are tokens, so they'd be skipped) or past a bracket, which starts or
    # ends a quote. Returns [first, last] token indices of each stretch a
    # quote can be in.
    QUOTE_BREAK = /[\p{L}#{BRACKETS.flatten.map { |b| Regexp.escape(b) }.join}]/

    def segments(text, tokens)
      segments = [[0, 0]]
      tokens.each_cons(2).with_index(1) do |(previous, token), index|
        if text[previous[2]...token[1]].match?(QUOTE_BREAK)
          segments << [index, index]
        else
          segments.last[1] = index
        end
      end
      segments
    end

    def shift(match, by)
      WordIndex::Match.new(match.token_start + by, match.token_end + by, match.word_start, match.word_end)
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

      (match.word_start..match.word_end).any? { |word| @verse_ids.include?(@index.verse_id(word)) }
    end

    def location_attributes(match, located)
      return {} unless located

      { from: @index.location(match.word_start), to: @index.location(match.word_end) }
    end

    # Character ranges inside ﴿ ﴾ or { } in a text
    def bracket_ranges(text)
      BRACKETS.flat_map do |open, close|
        ranges = []
        text.scan(/#{Regexp.escape(open)}[^#{Regexp.escape(close)}]*#{Regexp.escape(close)}?/) do
          match = Regexp.last_match
          ranges << (match.begin(0)...match.end(0))
        end
        ranges
      end
    end

    # The text node and offset in it of a character position in a run. A
    # quote's end belongs to the node it ends in, not the next one.
    def node_at(nodes, starts, position, ending:)
      nodes.each_with_index do |node, index|
        offset = position - starts[index]
        length = node.text.length
        return [node, offset] if ending ? offset.positive? && offset <= length : offset >= 0 && offset < length
      end
    end

    # Wraps the text from start_offset in start_node to end_offset in
    # end_node in a quote tag, splitting any markup it starts or ends inside
    def wrap(start_node, start_offset, end_node, end_offset, attributes)
      split_text(end_node, end_offset)
      quote_start = start_offset.zero? ? start_node : split_text(start_node, start_offset)
      end_node = quote_start if end_node == start_node

      container = (end_node.ancestors.to_a & quote_start.ancestors.to_a).first
      first = lift(quote_start, container, :start)
      last = lift(end_node, container, :end)

      element = container.document.create_element(TAG)
      attributes.each { |key, value| element["data-#{key}"] = value }
      first.add_previous_sibling(element)

      node = first
      loop do
        following = node.next_sibling
        element.add_child(node)
        break if node == last

        node = following
      end
    end

    # Cuts a text node at offset, returns the part after it
    def split_text(node, offset)
      text = node.text
      return if offset >= text.length

      rest = Nokogiri::XML::Text.new(text[offset..], node.document)
      node.content = text[0...offset]
      node.add_next_sibling(rest)
      rest
    end

    # Splits the elements between node and container, so node starts (or
    # ends) a child of container. Returns that child.
    def lift(node, container, side)
      while node.parent != container
        parent = node.parent
        cut = side == :start ? node.previous_sibling : node.next_sibling

        if cut
          clone = parent.document.create_element(parent.name)
          parent.attribute_nodes.each { |attribute| clone[attribute.name] = attribute.value }
          parent.add_next_sibling(clone)
          moving = side == :start ? [node] : []
          sibling = node.next_sibling
          while sibling
            moving << sibling
            sibling = sibling.next_sibling
          end
          moving.each { |child| clone.add_child(child) }
        end

        node = side == :start && cut ? clone : parent
      end

      node
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

    # A paragraph that only holds a quote is replaced by the quote, marked
    # data-display="block" to show it as a paragraph. The paragraph's
    # language and font classes don't apply to the quote, anything else (a
    # colour...) moves onto it.
    PARAGRAPHS = %w[p div].freeze
    PARAGRAPH_CLASSES = ['ar', 'arabic', OLD_CLASS].freeze

    def replace_paragraph(quote)
      paragraph = quote.parent
      return unless paragraph.respond_to?(:name) && PARAGRAPHS.include?(paragraph.name)
      return unless paragraph.element_children.size == 1 && paragraph.text.strip == quote.text.strip

      classes = (quote.classes + paragraph.classes - PARAGRAPH_CLASSES - [paragraph['lang']]).uniq
      quote['class'] = classes.join(' ') if classes.any?
      quote['data-display'] = 'block'
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
