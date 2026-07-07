require 'ostruct'

module Corpus
  module Morphology
    # Voice of a verb: whether the subject performs the action or receives it.
    # ACT — active voice, مبني للمعلوم — the subject does the action (كَتَبَ "he wrote").
    # PASS — passive voice, مبني للمجهول — the action is done to the subject (كُتِبَ "it was written").

    class VoiceType < OpenStruct
      ACTIVE  = new(tag: 'ACT')
      PASSIVE = new(tag: 'PASS')

      TAG_MAP = {
        'ACT'  => ACTIVE,
        'PASS' => PASSIVE
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when VoiceType
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
        TAG_MAP[tag] || raise(UnsupportedOperationException, "VoiceType tag #{tag} not recognized.")
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
