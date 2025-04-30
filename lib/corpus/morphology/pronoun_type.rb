module Corpus
  module Morphology
    class PronounType < OpenStruct
      OBJECT       = new(tag: "obj")
      SECOND_OBJECT = new(tag: "obj2")
      SUBJECT      = new(tag: "subj")

      # Map for fast lookup by tag
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

      # Parse the tag to return the corresponding PronounType object
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
