module Corpus
  module Morphology
    class FormType < OpenStruct
      FIRST   = new(tag: "I")
      SECOND  = new(tag: "II")
      THIRD   = new(tag: "III")
      FOURTH  = new(tag: "IV")
      FIFTH   = new(tag: "V")
      SIXTH   = new(tag: "VI")
      SEVENTH = new(tag: "VII")
      EIGHTH  = new(tag: "VIII")
      NINTH   = new(tag: "IX")
      TENTH   = new(tag: "X")
      ELEVENTH = new(tag: "XI")
      TWELFTH = new(tag: "XII")

      def to_s
        tag
      end

      def ==(other)
        case other
        when FormType
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
        [
          FIRST, SECOND, THIRD, FOURTH, FIFTH,
          SIXTH, SEVENTH, EIGHTH, NINTH, TENTH,
          ELEVENTH, TWELFTH
        ]
      end
    end
  end
end
