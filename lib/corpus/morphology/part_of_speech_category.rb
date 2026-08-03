module Corpus
  module Morphology
    # The classical three-way division of every Arabic word.
    # Nominal — اسم — nouns and everything noun-like (pronouns, adjectives, demonstratives): كِتَاب، هُوَ.
    # Verb — فعل — action words: قَالَ "he said".
    # Particle — حرف — function words that connect or modify: فِي، وَ، هَلْ.

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
