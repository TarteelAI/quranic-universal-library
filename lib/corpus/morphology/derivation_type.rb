module Corpus
  module Morphology
    class DerivationType < OpenStruct
      ACTIVE_PARTICIPLE  = new(tag: "ACT PCPL")
      PASSIVE_PARTICIPLE = new(tag: "PASS PCPL")
      VERBAL_NOUN        = new(tag: "VN")

      def to_s
        tag
      end

      def ==(other)
        case other
        when DerivationType
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
        [ACTIVE_PARTICIPLE, PASSIVE_PARTICIPLE, VERBAL_NOUN]
      end
    end
  end
end
