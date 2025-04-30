module Corpus
  module Morphology
    class PersonType < OpenStruct
      FIRST  = new(tag: "1")
      SECOND = new(tag: "2")
      THIRD  = new(tag: "3")

      # Map for fast lookup by tag
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

      # Parse the tag to return the corresponding PersonType object
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
