require 'ostruct'

module Corpus
  module Morphology
    # Case: the role a noun plays in its sentence, shown by its ending vowel.
    # Reading these endings (الإعراب) is the heart of Quranic grammar analysis.
    # NOM — nominative, مرفوع — subject or predicate; damma ending: اللَّهُ in قَالَ اللَّهُ "Allah said".
    # ACC — accusative, منصوب — object and similar roles; fatha ending: اللَّهَ in اتَّقُوا اللَّهَ "fear Allah".
    # GEN — genitive, مجرور — after a preposition or as possessor (إضافة); kasra ending: اللَّهِ in بِسْمِ اللَّهِ "in the name of Allah".

    class CaseType < OpenStruct
      NOMINATIVE = new(tag: "NOM")
      GENITIVE   = new(tag: "GEN")
      ACCUSATIVE = new(tag: "ACC")

      TAG_MAP = {
        "NOM" => NOMINATIVE,
        "GEN" => GENITIVE,
        "ACC" => ACCUSATIVE
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when CaseType
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
        TAG_MAP[tag] || raise(UnsupportedOperationException, "CaseType tag #{tag} not recognized.")
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
