require 'ostruct'

module Corpus
  module Morphology
    # Number: Arabic counts three grammatical numbers, not two like English.
    # S — singular, مفرد — one: كِتَاب "a book".
    # D — dual, مثنى — exactly two, marked by ـانِ/ـيْنِ: رَجُلَانِ "two men".
    # P — plural, جمع — three or more: مُؤْمِنُونَ "believers".

    class NumberType < OpenStruct
      SINGULAR = new(tag: "S")
      DUAL     = new(tag: "D")
      PLURAL   = new(tag: "P")

      TAG_MAP = {
        "S" => SINGULAR,
        "D" => DUAL,
        "P" => PLURAL
      }

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

      def self.parse(tag)
        TAG_MAP[tag] || raise(UnsupportedOperationException, "NumberType tag #{tag} not recognized.")
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
