module Utils
  module TextSanitizer
    class TafsirSanitizer < BaseSanitizer
      attr_accessor :split_text_into_para,
                    :resource_language

      # verse_ids: the ayahs the tafsir explains. Quran quotes are tagged with
      # <quran-text> (see QuranQuote::Tagger), these pick the right ayah when
      # the quoted words are in the Quran more than once.
      def sanitize(text, color_mapping: {}, class_mapping: {}, split_text: true, resource_language: nil,
                   verse_ids: nil, tag_quran: true)
        @fragment = Loofah.fragment(text)
        @split_text_into_para = split_text
        @resource_language = resource_language

        scrubber = TafsirScrubber.new(
          color_mapping: color_mapping,
          class_mapping: class_mapping,
        )

        @fragment.scrub!(scrubber)
        QuranQuote::Tagger.new(verse_ids: verse_ids).tag(@fragment) if tag_quran

        self
      end
    end
  end
end