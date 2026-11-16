module Morphology
  class TreebankLocalePresenter
    LOCALES = {
      'en' => { label: 'English', direction: 'ltr', css_class: '' },
      'ar' => { label: 'العربية', direction: 'rtl', css_class: 'ar' },
      'ur' => { label: 'اردو', direction: 'rtl', css_class: 'ur' },
      'ru' => { label: 'Русский', direction: 'ltr', css_class: '' }
    }.freeze

    DEFAULT = 'en'.freeze

    class << self
      def resolve(code)
        code = code.to_s
        LOCALES.key?(code) ? code : DEFAULT
      end

      def labels
        LOCALES.transform_values { |attrs| attrs[:label] }
      end

      def direction(code)
        fetch(code)[:direction]
      end

      def css_class(code)
        fetch(code)[:css_class]
      end

      private

      def fetch(code)
        LOCALES.fetch(code.to_s) { raise ArgumentError, "unsupported treebank locale: #{code.inspect}" }
      end
    end
  end
end
