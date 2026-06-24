require 'cgi'

module Search
  module Highlighter
    module_function

    def highlight(text, query, exact: false)
      text = text.to_s
      pattern = Pattern.new(query, exact: exact)
      return CGI.escapeHTML(text) if pattern.blank?

      ranges = exact ? raw_ranges(text, pattern) : normalized_ranges(text, pattern)
      render(text, ranges)
    end

    def highlight_contained(text, query, exact: false)
      text = text.to_s
      normalized_query = (exact ? query.to_s : ArabicNormalizer.normalize(query.to_s)).strip
      return CGI.escapeHTML(text) if normalized_query.empty?

      if exact
        normalized_text = text
        map = text.each_char.each_with_index.map { |_char, index| [index, index + 1] }
      else
        normalized_text, map = ArabicNormalizer.normalize_with_map(text)
      end

      range = contained_range(normalized_text, normalized_query)
      return CGI.escapeHTML(text) if range.nil?

      render(text, [[map[range[0]][0], map[range[1] - 1][0] + 1]])
    end

    def contained_range(normalized_text, normalized_query)
      tokens = []
      normalized_text.scan(/\S+/) { tokens << [Regexp.last_match.begin(0), Regexp.last_match.end(0)] }
      return nil if tokens.empty?

      count = tokens.length

      prefix = 0
      (1..count).each do |k|
        break unless normalized_query.include?(normalized_text[tokens[0][0]...tokens[k - 1][1]])

        prefix = k
      end

      suffix = 0
      (1..count).each do |k|
        break unless normalized_query.include?(normalized_text[tokens[count - k][0]...tokens[count - 1][1]])

        suffix = k
      end

      candidates = []
      candidates << [tokens[0][0], tokens[prefix - 1][1]] if prefix.positive?
      candidates << [tokens[count - suffix][0], tokens[count - 1][1]] if suffix.positive?
      candidates.max_by { |start, finish| finish - start }
    end

    def raw_ranges(text, pattern)
      regexp = pattern.highlight_regexp
      ranges = []
      cursor = 0
      while (match = regexp.match(text, cursor))
        break if match.end(0) == match.begin(0)

        ranges << [match.begin(0), match.end(0)]
        cursor = match.end(0)
      end
      ranges
    end

    def normalized_ranges(text, pattern)
      regexp = pattern.highlight_regexp
      normalized_text, map = ArabicNormalizer.normalize_with_map(text)

      ranges = []
      cursor = 0
      while (match = regexp.match(normalized_text, cursor))
        break if match.end(0) == match.begin(0)

        last = match.end(0) - 1
        ranges << [map[match.begin(0)][0], map[last][0] + 1]
        cursor = match.end(0)
      end
      ranges
    end

    def render(text, ranges)
      return CGI.escapeHTML(text) if ranges.empty?

      output = +''
      cursor = 0
      ranges.each do |start, finish|
        output << CGI.escapeHTML(text[cursor...start]) if start > cursor
        output << '<mark>' << CGI.escapeHTML(text[start...finish]) << '</mark>'
        cursor = finish
      end
      output << CGI.escapeHTML(text[cursor..]) if cursor < text.length
      output
    end
  end
end
