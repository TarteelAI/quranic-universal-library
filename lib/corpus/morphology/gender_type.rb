require 'ostruct'

module Corpus
  module Morphology
    class GenderType < OpenStruct
      MASCULINE = new(tag: "M")
      FEMININE  = new(tag: "F")

      def to_s
        tag
      end

      def ==(other)
        case other
        when GenderType
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
        [MASCULINE, FEMININE]
      end
    end
  end
end
