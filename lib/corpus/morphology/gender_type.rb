require 'ostruct'

module Corpus
  module Morphology
    # Gender: every Arabic noun is either masculine or feminine, and verbs,
    # adjectives and pronouns referring to it must agree.
    # M — masculine, مذكر: مُؤْمِن "believing man".
    # F — feminine, مؤنث — often marked with ة: مُؤْمِنَة "believing woman".

    class GenderType < OpenStruct
      MASCULINE = new(tag: "M")
      FEMININE  = new(tag: "F")

      TAG_MAP = {
        "M" => MASCULINE,
        "F" => FEMININE
      }

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

      def self.parse(tag)
        TAG_MAP[tag] || raise(UnsupportedOperationException, "GenderType tag #{tag} not recognized.")
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
