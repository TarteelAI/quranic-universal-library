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
    # Brackets that may hold a quote. ( ) and [ ] also hold ayah numbers in
    # the middle of a quote, so unlike BRACKETS they don't end one.
    UNIT_BRACKETS = (BRACKETS + [['(', ')'], ['[', ']'], ['«', '»']]).freeze

    # Markup a quote can run through. Anything else (p, div, br, li...) ends
    # the text a quote is looked for in.
    INLINE_ELEMENTS = %w[span b strong i em u a sup sub small mark del ins font abbr].freeze

    # How many words a quote needs before it's tagged. Arabic tafsirs repeat
    # Quran words all the time while explaining them, so plain text needs a
    # few. A marked quote needs fewer, and fewer again when it's from the
    # ayahs the tafsir explains (verse_ids). A quote is marked when it's
    # inside ﴿ ﴾, or when it's the whole of the Arabic in:
    #
    # - an inline element (a highlighted span, bold...) or any element with
    #   the qpc-hafs class. Not a plain paragraph, a short Arabic paragraph
    #   is as likely a heading.
    # - brackets: { } ( ) [ ] « »
    # - the Arabic between words in another language, like an English
    #   tafsir quoting Arabic. Not in an Arabic paragraph, where it would be
    #   any explanation between two quotes.
    #
    # Being inside a qpc-hafs element isn't enough on its own, tafsirs put
    # the class on hadith too.
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

      match, located = pick(@index.matches_at(tokens, 0)) { true }
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

      segments = segments(text, tokens)
      units = units(text, tokens, nodes, starts, segments)
      quote_brackets = bracket_ranges(text, [[OPEN_BRACKET, CLOSE_BRACKET]])
      marked = lambda do |match|
        quote_brackets.any? { |range| range.cover?(tokens[match.token_start][1]) } ||
          units.include?([match.token_start, match.token_end])
      end
      quotes = []

      segments.each do |first, last|
        words = tokens[first..last].map(&:first)
        position = 0

        while position < words.size
          match, located = pick(candidates(words, position, first, units), &marked)

          if match
            quotes << [match, located]
            position = match.token_end - first + 1
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

    # Places the words from position on match, as token indices of the run.
    # Besides the longest match from each place, the match cut at the end of
    # a unit starting here, so a quote filling a span still counts as marked
    # when the Quran words carry on after the span.
    def candidates(words, position, first, units)
      unit_ends = units.filter_map { |start, last| last - first if start == first + position && last - first < words.size - 1 }
      [words.size - 1, *unit_ends].uniq.flat_map do |last|
        @index.matches_at(words[0..last], position).map { |match| shift(match, first) }
      end
    end

    # Token ranges [first, last] a quote that fills them counts as marked:
    # each element's Arabic, each bracket's, and each stretch between words
    # in another language
    def units(text, tokens, nodes, starts, segments)
      units = Set.new
      units.merge(segments) if text.match?(OTHER_LANGUAGE)

      token_nodes = tokens.map { |_, start, _| starts.rindex { |node_start| node_start <= start } }
      by_element = Hash.new { |hash, element| hash[element] = [] }
      token_nodes.each_with_index.group_by(&:first).each do |node_index, pairs|
        nodes[node_index].ancestors.each do |ancestor|
          by_element[ancestor].concat(pairs.map(&:last)) if marking_element?(ancestor)
        end
      end
      by_element.each_value { |indices| units << [indices.min, indices.max] }

      bracket_ranges(text, UNIT_BRACKETS).each do |range|
        inside = tokens.each_index.select { |index| range.cover?(tokens[index][1]) }
        units << [inside.min, inside.max] if inside.any?
      end

      units
    end

    OTHER_LANGUAGE = /[\p{L}&&\P{Arabic}]/

    def marking_element?(node)
      node.element? && (INLINE_ELEMENTS.include?(node.name) || node.classes.include?(OLD_CLASS))
    end

    def shift(match, by)
      WordIndex::Match.new(match.token_start + by, match.token_end + by, match.word_start, match.word_end)
    end

    # The longest match that has enough words, preferring the tafsir's ayahs.
    # Returns [match, located]: located is false when the same words are in
    # more than one place and nothing says which.
    def pick(candidates, &marked)
      qualifying = candidates.select { |m| m.size >= MIN_WORDS[[marked.call(m), in_range?(m)]] }
      return if qualifying.empty?

      size = qualifying.map(&:size).max
      longest = qualifying.select { |m| m.size == size }
      in_range = longest.select { |m| in_range?(m) }
      match = in_range.first || longest.first

      located = in_range.any? || longest.map(&:word_start).uniq.size == 1
      # Plain text that's in the Quran in several places is more likely a
      # common phrase (in a hadith, a dua...) than a quote
      return if !marked.call(match) && !located

      [match, located]
    end

    def in_range?(match)
      return false if @verse_ids.blank?

      (match.word_start..match.word_end).any? { |word| @verse_ids.include?(@index.verse_id(word)) }
    end

    def location_attributes(match, located)
      return {} unless located

      { from: @index.location(match.word_start), to: @index.location(match.word_end) }
    end

    # Character ranges inside the brackets in a text
    def bracket_ranges(text, brackets = BRACKETS)
      brackets.flat_map do |open, close|
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
