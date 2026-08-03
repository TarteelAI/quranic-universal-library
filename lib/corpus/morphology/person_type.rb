module Corpus
  module Morphology
    # Person: who a verb or pronoun points to, relative to the speaker.
    # 1 — first person, المتكلم — the speaker (I/we): نَعْبُدُ "we worship" (1:5).
    # 2 — second person, المخاطب — the one addressed (you): تَعْبُدُونَ "you worship".
    # 3 — third person, الغائب — the one spoken about (he/she/they): يَعْبُدُونَ "they worship".

    class PersonType < OpenStruct
      FIRST  = new(tag: "1")
      SECOND = new(tag: "2")
      THIRD  = new(tag: "3")

      TAG_MAP = {
        "1" => FIRST,
        "2" => SECOND,
        "3" => THIRD
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when PersonType
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
        person_type = TAG_MAP[tag]
        if person_type.nil?
          raise UnsupportedOperationException, "PersonType tag #{tag} not recognized."
        end
        person_type
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
