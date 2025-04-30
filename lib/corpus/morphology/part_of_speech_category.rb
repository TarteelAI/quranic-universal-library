module Corpus
  module Morphology
    class PartOfSpeechCategory < OpenStruct
      NOMINAL  = new(tag: "Nominal")
      VERB     = new(tag: "Verb")
      PARTICLE = new(tag: "Particle")

      TAG_MAP = {
        "Nominal"  => NOMINAL,
        "Verb"     => VERB,
        "Particle" => PARTICLE
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when PartOfSpeechCategory
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

      # Parse the tag to return the corresponding PartOfSpeechCategory
      def self.parse(tag)
        category = TAG_MAP[tag]
        if category.nil?
          raise UnsupportedOperationException, "Part of speech category tag #{tag} not recognized."
        end
        category
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
