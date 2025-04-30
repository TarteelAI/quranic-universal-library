module Corpus
  module Morphology
    class SegmentType < OpenStruct
      PREFIX = new(tag: "Prefix")
      STEM   = new(tag: "Stem")
      SUFFIX = new(tag: "Suffix")

      TAG_MAP = {
        "Prefix" => PREFIX,
        "Stem"   => STEM,
        "Suffix" => SUFFIX
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when SegmentType
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

      # Parse the tag to return the corresponding SegmentType object
      def self.parse(tag)
        segment_type = TAG_MAP[tag]
        if segment_type.nil?
          raise UnsupportedOperationException, "SegmentType tag #{tag} not recognized."
        end
        segment_type
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
