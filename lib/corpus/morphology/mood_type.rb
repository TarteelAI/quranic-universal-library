module Corpus
  module Morphology
    class MoodType < OpenStruct
      INDICATIVE   = new(tag: "IND")
      SUBJUNCTIVE  = new(tag: "SUBJ")
      JUSSIVE      = new(tag: "JUS")

      TAG_MAP = {
        "IND"  => INDICATIVE,
        "SUBJ" => SUBJUNCTIVE,
        "JUS"  => JUSSIVE
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when MoodType
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
        TAG_MAP[tag]
      end

      def self.all
        [INDICATIVE, SUBJUNCTIVE, JUSSIVE]
      end
    end
  end
end
