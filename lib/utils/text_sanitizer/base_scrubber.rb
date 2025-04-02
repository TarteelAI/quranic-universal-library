module Utils
  module TextSanitizer
    class BaseScrubber < Rails::Html::PermitScrubber
      DEBUG = false

      LINK_NODE = 'a'.freeze
      TARGET_HOSTS = []
      attr_accessor :color_mapping
      attr_accessor :class_mapping

      ALLOWED_CLASS_VALUES = [
        'arabic',
        'qpc-hafs',
        'indopak-nastaleeq',
        'blue',
        'red',
        'reference', 'ayah-ref', 'hlt',
        'green',
        'brown',
        'gray',
        'info',
        'translation',

        'hadith', 'quran',
        'footnote' # Temp, need to parse the footnotes from Abu Adel Russian translation
      ]

      def initialize(class_mapping: {}, color_mapping: {})
        super()

        @class_mapping = HashWithIndifferentAccess.new(class_mapping)
        @color_mapping = HashWithIndifferentAccess.new(color_mapping)
        self.tags = %w(strong em tag b i pre a sup sub span div del ins p blockquote br ul ol li h1 h2 h3 h4).freeze
        self.attributes = %w(lang xml:lang ayah-range word-range class data-id).freeze
      end

      def scrub(node)
        if node.text?
          if node.text.strip.blank?
            node.remove
            return STOP
          end

          if node.text.ends_with?("\n")
            node.before(node.text.strip) # strip
            node.remove
            return STOP
          end
        end

        super node
      end

      protected

      def scrub_attributes(node)
        style = node.attributes['style']
        classes = []

        node_classes = node.get_attribute('class').to_s.split(/\s+/).compact_blank
        node_classes.each do |css_class|
          klass = class_mapping[css_class] || css_class
          classes.push(klass.split(/\s+/).compact_blank) if klass.present?
        end

        if style.present?
          if (color = Utils::CssStyle.parse(style)['color']).present?
            classes << color_mapping[color.tr('#', '').to_sym].to_s.split(/\s+/)
          end
        end

        classes = classes.flatten.select do |c|
          ALLOWED_CLASS_VALUES.include?(c)
        end

        if classes.present?
          node.set_attribute('class', classes.join(' '))
        else
          node.remove_attribute('class')
        end

        super(node)
      end

      def is_link?(node)
        LINK_NODE == node.name
      end

      def open_in_new_tab(node)
        if external_link?(node.attr('href'))
          node.set_attribute('target', '_blank')
        end
      end

      def external_link?(path)
        if path
          host = begin
                   URI(path).host
                 rescue URI::InvalidURIError => e
                   # TODO: track and fix these links
                   nil
                 end

          return false if host.nil?
          !TARGET_HOSTS.include?(host)
        end
      end
    end
  end
end