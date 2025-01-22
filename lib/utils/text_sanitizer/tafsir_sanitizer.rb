module Utils
  module TextSanitizer
    class TafsirSanitizer < BaseSanitizer
      attr_accessor :split_text_into_para,
                    :resource_language

      def sanitize(text, color_mapping: {}, class_mapping: {}, split_text: true, resource_language: nil)
        @fragment = Loofah.fragment(text)
        @split_text_into_para = split_text
        @resource_language = resource_language

        scrubber = TafsirScrubber.new(
          color_mapping: color_mapping,
          class_mapping: class_mapping,
        )

        @fragment.scrub!(scrubber)

        self
      end
    end
  end
end