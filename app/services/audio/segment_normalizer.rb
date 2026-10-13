# frozen_string_literal: true

require 'json'

module Audio
  # Normalises word-segment data before it hits the DB.
  #
  # Two problems this guards against:
  # 1. The CMS edit form submits the jsonb `segments` column as a plain string,
  #    and Rails happily stores a String inside jsonb. Every reader that calls
  #    `segments.map` then 500s (segment builder, API, validators).
  # 2. The segment builder pads incomplete repeats with placeholder words
  #    (`[4]`, no times). Those arrive as `[4, 0, 0]` and should not be saved.
  module SegmentNormalizer
    module_function

    # Coerce whatever was assigned to a plain Array, or nil if it can't be parsed.
    # Accepts arrays, JSON strings, and Ruby inspect output such as
    # `[[1, 10, 20, {"waqaf"=>true}]]` which is what the old CMS form submitted.
    def parse(value)
      return nil if value.nil?
      return value if value.is_a?(Array)
      return parse(value.values) if value.respond_to?(:values) && !value.is_a?(String)

      string = value.to_s.strip
      return [] if string.empty?

      JSON.parse(string)
    rescue JSON::ParserError
      begin
        JSON.parse(string.gsub(/:([a-zA-Z_]\w*)\s*=>/, '"\1"=>').gsub('=>', ':'))
      rescue JSON::ParserError
        nil
      end
    end

    # Drop entries that carry no timing: malformed rows (fewer than 2 items) and
    # placeholders whose start and end are both 0.
    def clean(list)
      Array(list).reject do |segment|
        next true unless segment.is_a?(Array)
        next true if segment.size < 2

        segment[1].to_i.zero? && segment[2].to_i.zero?
      end
    end

    def parse_and_clean(value)
      parsed = parse(value)
      parsed.nil? ? nil : clean(parsed)
    end
  end
end
