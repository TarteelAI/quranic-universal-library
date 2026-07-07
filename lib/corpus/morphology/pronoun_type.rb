module Corpus
  module Morphology
    # Role of a pronoun attached to a verb as a suffix.
    # subj — subject, فاعل — the doer: the تُ in كَتَبْتُ "I wrote".
    # obj — object, مفعول به — done to: the هُ in خَلَقَهُ "He created him".
    # obj2 — second object of verbs that take two: the هَا in أَنُلْزِمُكُمُوهَا
    #   "shall We compel you (كُم, obj) to it (هَا, obj2)?" (11:28).

    class PronounType < OpenStruct
      OBJECT       = new(tag: "obj")
      SECOND_OBJECT = new(tag: "obj2")
      SUBJECT      = new(tag: "subj")

      TAG_MAP = {
        "obj"  => OBJECT,
        "obj2" => SECOND_OBJECT,
        "subj" => SUBJECT
      }

      def to_s
        tag
      end

      def cast(value)
        TAG_MAP[value]
      end

      def serialize(value)
        value.to_s
      end

      def ==(other)
        case other
        when PronounType
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
        pronoun_type = TAG_MAP[tag]
        if pronoun_type.nil?
          raise UnsupportedOperationException, "PronounType tag #{tag} not recognized."
        end
        pronoun_type
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
