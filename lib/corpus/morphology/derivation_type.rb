require 'ostruct'

module Corpus
  module Morphology
    # Derivation: nouns built from a verb's root that keep its action meaning,
    # naming the doer, the receiver, or the act itself.
    # ACT PCPL — active participle, اسم فاعل — the doer: كاتب "writer".
    # PASS PCPL — passive participle, اسم مفعول — the receiver: مكتوب "written".
    # VN — verbal noun, مصدر — the action itself: كتابة "writing".

    class DerivationType < OpenStruct
      ACTIVE_PARTICIPLE  = new(tag: "ACT PCPL")
      PASSIVE_PARTICIPLE = new(tag: "PASS PCPL")
      VERBAL_NOUN        = new(tag: "VN")

      TAG_MAP = {
        "ACT PCPL"  => ACTIVE_PARTICIPLE,
        "PASS PCPL" => PASSIVE_PARTICIPLE,
        "VN"        => VERBAL_NOUN
      }

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

      def self.parse(tag)
        TAG_MAP[tag] || raise(UnsupportedOperationException, "DerivationType tag #{tag} not recognized.")
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
