module Corpus
  module Morphology
    class NumberType < OpenStruct
      SINGULAR = new(tag: "S")
      DUAL     = new(tag: "D")
      PLURAL   = new(tag: "P")

      def to_s
        tag
      end

      def ==(other)
        case other
        when NumberType
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

      def hash
        tag.hash
      end

      def self.all
        [SINGULAR, DUAL, PLURAL]
      end
    end
  end
end
