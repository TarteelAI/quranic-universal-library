module Corpus
  module Morphology
    class CaseType < OpenStruct
      NOMINATIVE = new(tag: "NOM")
      GENITIVE   = new(tag: "GEN")
      ACCUSATIVE = new(tag: "ACC")

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

      def self.all
        [NOMINATIVE, GENITIVE, ACCUSATIVE]
      end
    end
  end
end
