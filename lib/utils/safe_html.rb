# frozen_string_literal: true

module Utils
  # Cleans stored HTML before it is rendered as raw markup.
  #
  # Translations, tafsirs, footnotes and user suggestions carry their own
  # markup (custom attributes like foot_note, ayah-range, classes, data-*),
  # so a tag allowlist would break them. Instead this removes only what can
  # run code: script-like elements, on* event handlers, srcdoc, and
  # javascript:/vbscript:/data: URLs (data: images are kept).
  #
  # Inline SVG is allowed (some tafsirs ship diagrams), so SVG's own ways of
  # running script are handled too: SMIL animation elements (animate, set...)
  # can write a javascript: URL into an href through `to`/`values`/`from`/`by`,
  # which are not URL attributes themselves.
  class SafeHtml
    BLOCKED_ELEMENTS = %w[
      script style iframe frame frameset object embed applet base link meta
      form input button textarea select noscript template portal
      handler listener
    ].freeze

    # SVG animation elements. They're kept for harmless animations (opacity,
    # transforms) but removed when they target a URL or event attribute, and
    # their value attributes are checked like URLs.
    ANIMATION_ELEMENTS = %w[animate set animatemotion animatetransform animatecolor].freeze
    ANIMATION_VALUE_ATTRIBUTES = %w[to from by values].freeze

    URL_ATTRIBUTES = %w[
      href src xlink:href action formaction poster background lowsrc dynsrc
      data srcset cite longdesc xml:base
    ].freeze

    UNSAFE_URL = /\A(javascript|vbscript|data):/i
    SAFE_DATA_URL = %r{\Adata:image/(png|jpe?g|gif|webp);}i

    def self.sanitize(html)
      return ''.html_safe if html.blank?

      fragment = Loofah.html5_fragment(html.to_s)
      fragment.scrub!(Scrubber.new)
      fragment.to_s.html_safe
    end

    class Scrubber < Loofah::Scrubber
      def initialize
        super
        @direction = :top_down
      end

      def scrub(node)
        return CONTINUE unless node.element?

        element = node.name.downcase

        if BLOCKED_ELEMENTS.include?(element) || unsafe_animation?(node, element)
          node.remove
          return STOP
        end

        node.attribute_nodes.each do |attr|
          name = attribute_name(attr)

          if name.start_with?('on') || name == 'srcdoc' || name == 'formaction'
            attr.remove
          elsif URL_ATTRIBUTES.include?(name) && unsafe_url?(attr.value)
            attr.remove
          elsif ANIMATION_ELEMENTS.include?(element) && ANIMATION_VALUE_ATTRIBUTES.include?(name) && unsafe_animation_value?(attr.value)
            attr.remove
          elsif name == 'style' && unsafe_style?(attr.value)
            attr.remove
          end
        end

        CONTINUE
      end

      private

      # Foreign (SVG/MathML) attributes may come back as `href` in the xlink
      # namespace rather than a literal `xlink:href`
      def attribute_name(attr)
        name = attr.name.downcase
        prefix = attr.namespace&.prefix
        prefix.present? && !name.include?(':') ? "#{prefix.downcase}:#{name}" : name
      end

      # An animation that sets an href (or any URL/event attribute) can swap
      # in a javascript: URL at runtime, so drop it entirely
      def unsafe_animation?(node, element)
        return false unless ANIMATION_ELEMENTS.include?(element)

        target = node['attributeName'] || node['attributename']
        return false if target.blank?

        target = normalize(target).downcase
        local = target.split(':').last.to_s

        target.start_with?('on') || local.start_with?('on') ||
          URL_ATTRIBUTES.include?(target) || URL_ATTRIBUTES.include?(local) ||
          %w[style srcdoc].include?(local)
      end

      # `values` is a ;-separated list, any entry can be the payload
      def unsafe_animation_value?(value)
        value.to_s.split(';').any? { |v| unsafe_url?(v) || normalize(v).downcase.include?('javascript:') }
      end

      def unsafe_url?(value)
        normalized = normalize(value)
        normalized.match?(UNSAFE_URL) && !normalized.match?(SAFE_DATA_URL)
      end

      # Browsers ignore whitespace and control chars inside the scheme
      def normalize(value)
        value.to_s.gsub(/[\u0000- \u007F]+/, '')
      end

      def unsafe_style?(value)
        value.to_s.gsub(/\s+/, '').downcase.match?(/expression\(|javascript:|vbscript:|-moz-binding|behavior:/)
      end
    end
  end
end
