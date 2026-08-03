module Corpus
  module Morphology
    # Segment: one written Quranic word often packs several grammatical units;
    # segmentation splits it so each unit can be tagged on its own.
    # Prefix — attached particle before the stem: the بِ in بِسْمِ "in (the) name".
    # Stem — the core unit carrying the root meaning: the سْمِ in بِسْمِ.
    # Suffix — attached pronoun/particle after the stem: the هِمْ in عَلَيْهِمْ "upon them".

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
