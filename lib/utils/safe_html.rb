# frozen_string_literal: true

module Utils
  # Cleans stored HTML before it is rendered as raw markup.
  #
  # Translations, tafsirs, footnotes and user suggestions carry their own
  # markup (custom attributes like foot_note, ayah-range, classes, data-*),
  # so a tag allowlist would break them. Instead this removes only what can
  # run code: script-like elements, on* event handlers, srcdoc, and
  # javascript:/vbscript:/data: URLs (data: images are kept).
  class SafeHtml
    BLOCKED_ELEMENTS = %w[
      script style iframe frame frameset object embed applet base link meta
      form input button textarea select noscript template portal
    ].freeze

    URL_ATTRIBUTES = %w[
      href src xlink:href action formaction poster background lowsrc dynsrc
      data srcset cite longdesc
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

        if BLOCKED_ELEMENTS.include?(node.name.downcase)
          node.remove
          return STOP
        end

        node.attribute_nodes.each do |attr|
          name = attr.name.downcase

          if name.start_with?('on') || name == 'srcdoc' || name == 'formaction'
            attr.remove
          elsif URL_ATTRIBUTES.include?(name) && unsafe_url?(attr.value)
            attr.remove
          elsif name == 'style' && unsafe_style?(attr.value)
            attr.remove
          end
        end

        CONTINUE
      end

      private

      def unsafe_url?(value)
        # Browsers ignore whitespace and control chars inside the scheme
        normalized = value.to_s.gsub(/[\u0000- \u007F]+/, '')
        normalized.match?(UNSAFE_URL) && !normalized.match?(SAFE_DATA_URL)
      end

      def unsafe_style?(value)
        value.to_s.gsub(/\s+/, '').downcase.match?(/expression\(|javascript:|vbscript:|-moz-binding|behavior:/)
      end
    end
  end
end
