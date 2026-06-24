module Search
  class Pattern
    GAP = /(\{[^{}]*\}\*?|\*)/

    Token = Struct.new(:kind, :regex, :like, :word_gap)

    def initialize(query, exact: false)
      @raw = query.to_s.strip
      @exact = exact
      parse
    end

    def blank?
      @tokens.none? { |token| token.kind == :literal }
    end

    def word_gap?
      @tokens.any?(&:word_gap)
    end

    def like
      body = @tokens.map { |token| token.kind == :literal ? token.like : '%' }.join
      "#{@anchor_start ? '' : '%'}#{body}#{@anchor_end ? '' : '%'}"
    end

    def sql_regex
      "#{@anchor_start ? '^' : ''}#{core}#{@anchor_end ? '$' : ''}"
    end

    def match_regexp
      source = "#{@anchor_start ? '\\A' : ''}#{core}#{@anchor_end ? '\\z' : ''}"
      Regexp.new(source, Regexp::IGNORECASE)
    end

    def highlight_regexp
      Regexp.new(core_without_edge_gaps, Regexp::IGNORECASE)
    end

    def self.sql_escape(string)
      string.gsub(/[\\%_]/) { |char| "\\#{char}" }
    end

    private

    def core
      @tokens.map(&:regex).join
    end

    def core_without_edge_gaps
      tokens = @tokens.dup
      tokens.shift while tokens.first && tokens.first.kind == :gap
      tokens.pop while tokens.last && tokens.last.kind == :gap
      tokens.map(&:regex).join
    end

    def parse
      text = @raw
      @anchor_start = text.start_with?('^')
      text = text[1..] if @anchor_start
      @anchor_end = text.end_with?('$')
      text = text[0...-1] if @anchor_end

      @tokens = []
      text.split(GAP, -1).each_with_index do |piece, index|
        index.odd? ? add_gap(piece) : add_literal(piece)
      end
    end

    def add_literal(piece)
      literal = transform(piece.strip)
      return if literal.empty?

      @tokens << Token.new(:literal, Regexp.escape(literal), self.class.sql_escape(literal), false)
    end

    def add_gap(token)
      if token == '*'
        @tokens << Token.new(:gap, '.*?', '%', false)
      else
        spec = token[1...token.index('}')]

        @tokens << Token.new(:gap, "\\s+(?:\\S+\\s+)#{bound(spec)}", nil, true)
      end
    end

    def bound(spec)
      spec = spec.to_s.strip
      case spec
      when /\A(\d+)\z/    then "{#{Regexp.last_match(1)}}"
      when /\A>=(\d+)\z/  then "{#{Regexp.last_match(1)},}"
      when /\A>(\d+)\z/   then "{#{Regexp.last_match(1).to_i + 1},}"
      when /\A<=(\d+)\z/  then "{0,#{Regexp.last_match(1)}}"
      when /\A<(\d+)\z/   then "{0,#{[Regexp.last_match(1).to_i - 1, 0].max}}"
      when /\A(\d+),(\d+)\z/ then "{#{Regexp.last_match(1)},#{Regexp.last_match(2)}}"
      else '*'
      end
    end

    def transform(segment)
      @exact ? segment : ArabicNormalizer.normalize(segment)
    end
  end
end
