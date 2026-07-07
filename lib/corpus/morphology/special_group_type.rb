require 'ostruct'

module Corpus
  module Morphology
    # Families of special governing words that change the case of the nominal
    # sentence they enter ("sisters" = words behaving like the family head).
    # kana — كان وأخواتها — "to be/become" verbs (كَانَ، أَصْبَحَ، لَيْسَ، ظَلَّ); make their predicate accusative.
    # inna — إنّ وأخواتها — emphasis particles (إِنَّ، أَنَّ، لَكِنَّ، لَعَلَّ، لَيْتَ); make their subject accusative.
    # kada — كاد وأخواتها — "almost/begin to" verbs (كَادَ، عَسَىٰ); take an imperfect-verb predicate.
    # Display names come from i18n: morphology.special_groups.<tag>.

    class SpecialGroupType < OpenStruct
      KANA = new(tag: 'kana')
      INNA = new(tag: 'inna')
      KADA = new(tag: 'kada')

      TAG_MAP = {
        'kana' => KANA,
        'inna' => INNA,
        'kada' => KADA
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when SpecialGroupType
          tag == other.tag
        when String
          tag == other
        else
          false
        end
      end

      def eql?(other)
        self == other
      end

      def self.parse(tag)
        TAG_MAP[tag] || raise(UnsupportedOperationException, "SpecialGroupType tag #{tag} not recognized.")
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
