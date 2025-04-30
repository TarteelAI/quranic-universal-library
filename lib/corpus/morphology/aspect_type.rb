module Corpus
  module Morphology
    class AspectType < OpenStruct
      PERFECT    = new(tag: "PERF")
      IMPERFECT  = new(tag: "IMPF")
      IMPERATIVE = new(tag: "IMPV")

      def to_s
        tag
      end

      def ==(other)
        case other
        when AspectType
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
        [PERFECT, IMPERFECT, IMPERATIVE]
      end
    end
  end
end
