module Utils
  # A utils for parsing css rules
  # Utils::CssStyle.parse "color:red; border: 2px solid red"
  # -> {"color"=>"red", "border"=>"2px solid red"
  class CssStyle
    class << self
      def parse(style_string)
        rules = clean_up_rules(style_string)
        props = rules.map do |rule|
          parse_style_props(rule)
        end

        style_mapping props
      end

      protected

      def clean_up_rules(style_string)
        style_string.
          to_s.
          split(';').
          reject { |s| s.presence.nil? }
      end

      def parse_style_props(property_string)
        parts = property_string.split(':', 2)
        return nil if parts&.length != 2
        return nil if parts.any? { |s| s.nil? }

        { key: parts[0].strip.downcase, value: parts[1].strip.downcase }
      end

      def style_mapping(properties)
        properties.reduce({}) do |accum, property|
          accum[property[:key]] = property[:value]
          accum
        end
      end
    end
  end
end
