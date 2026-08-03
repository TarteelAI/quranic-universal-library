require 'ostruct'

module Corpus
  module Morphology
    # Aspect: whether a verb's action is completed, ongoing, or commanded.
    # Arabic verbs don't mark past/present/future tense the way English does;
    # the verb's shape signals one of these three aspects instead.
    # PERF — perfect, الماضي — completed action: قَالَ "he said".
    # IMPF — imperfect, المضارع — ongoing or incomplete action: يَقُولُ "he says".
    # IMPV — imperative, الأمر — a command: اقْرَأْ "read!" (96:1).

    class AspectType < OpenStruct
      PERFECT    = new(tag: "PERF")
      IMPERFECT  = new(tag: "IMPF")
      IMPERATIVE = new(tag: "IMPV")

      TAG_MAP = {
        "PERF" => PERFECT,
        "IMPF" => IMPERFECT,
        "IMPV" => IMPERATIVE
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when AspectType
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
        TAG_MAP[tag] || raise(UnsupportedOperationException, "AspectType tag #{tag} not recognized.")
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
