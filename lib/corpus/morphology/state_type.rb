require 'ostruct'

module Corpus
  module Morphology
    # Definiteness: whether a noun names something specific or unspecific;
    # indefinite nouns usually carry tanwin (ـٌ ـً ـٍ).
    # DEF — definite, معرفة — a specific known thing: الْكِتَابُ "the book".
    # INDEF — indefinite, نكرة — an unspecific thing: كِتَابٌ "a book".

    class StateType < OpenStruct
      DEFINITE   = new(tag: 'DEF')
      INDEFINITE = new(tag: 'INDEF')

      TAG_MAP = {
        'DEF'   => DEFINITE,
        'INDEF' => INDEFINITE
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when StateType
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
        TAG_MAP[tag] || raise(UnsupportedOperationException, "StateType tag #{tag} not recognized.")
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
