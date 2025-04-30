module Corpus
  module Morphology
    class PartOfSpeech < OpenStruct
      NOUN                    = new(tag: "N")
      PROPER_NOUN             = new(tag: "PN")
      PRONOUN                 = new(tag: "PRON")
      DEMONSTRATIVE           = new(tag: "DEM")
      RELATIVE                = new(tag: "REL")
      ADJECTIVE               = new(tag: "ADJ")
      VERB                    = new(tag: "V")
      PREPOSITION             = new(tag: "P")
      INTERROGATIVE           = new(tag: "INTG")
      VOCATIVE                = new(tag: "VOC")
      NEGATIVE                = new(tag: "NEG")
      EMPHATIC                = new(tag: "EMPH")
      PURPOSE                 = new(tag: "PRP")
      IMPERATIVE              = new(tag: "IMPV")
      FUTURE                  = new(tag: "FUT")
      CONJUNCTION             = new(tag: "CONJ")
      DETERMINER              = new(tag: "DET")
      INITIALS                = new(tag: "INL")
      TIME                    = new(tag: "T")
      LOCATION                = new(tag: "LOC")
      ACCUSATIVE              = new(tag: "ACC")
      CONDITIONAL             = new(tag: "COND")
      SUBORDINATING_CONJUNCTION = new(tag: "SUB")
      RESTRICTION             = new(tag: "RES")
      EXCEPTIVE               = new(tag: "EXP")
      AVERSION                = new(tag: "AVR")
      CERTAINTY               = new(tag: "CERT")
      RETRACTION              = new(tag: "RET")
      PREVENTIVE              = new(tag: "PREV")
      ANSWER                  = new(tag: "ANS")
      INCEPTIVE               = new(tag: "INC")
      SURPRISE                = new(tag: "SUR")
      SUPPLEMENTAL            = new(tag: "SUP")
      EXHORTATION             = new(tag: "EXH")
      IMPERATIVE_VERBAL_NOUN  = new(tag: "IMPN")
      EXPLANATION             = new(tag: "EXL")
      EQUALIZATION            = new(tag: "EQ")
      RESUMPTION              = new(tag: "REM")
      CAUSE                   = new(tag: "CAUS")
      AMENDMENT               = new(tag: "AMD")
      PROHIBITION             = new(tag: "PRO")
      CIRCUMSTANTIAL          = new(tag: "CIRC")
      RESULT                  = new(tag: "RSLT")
      INTERPRETATION          = new(tag: "INT")
      COMITATIVE              = new(tag: "COM")

      TAG_MAP = {
        "N"   => NOUN,
        "PN"  => PROPER_NOUN,
        "PRON"=> PRONOUN,
        "DEM" => DEMONSTRATIVE,
        "REL" => RELATIVE,
        "ADJ" => ADJECTIVE,
        "V"   => VERB,
        "P"   => PREPOSITION,
        "INTG"=> INTERROGATIVE,
        "VOC" => VOCATIVE,
        "NEG" => NEGATIVE,
        "EMPH"=> EMPHATIC,
        "PRP" => PURPOSE,
        "IMPV"=> IMPERATIVE,
        "FUT" => FUTURE,
        "CONJ"=> CONJUNCTION,
        "DET" => DETERMINER,
        "INL" => INITIALS,
        "T"   => TIME,
        "LOC" => LOCATION,
        "ACC" => ACCUSATIVE,
        "COND"=> CONDITIONAL,
        "SUB" => SUBORDINATING_CONJUNCTION,
        "RES" => RESTRICTION,
        "EXP" => EXCEPTIVE,
        "AVR" => AVERSION,
        "CERT"=> CERTAINTY,
        "RET" => RETRACTION,
        "PREV"=> PREVENTIVE,
        "ANS" => ANSWER,
        "INC" => INCEPTIVE,
        "SUR" => SURPRISE,
        "SUP" => SUPPLEMENTAL,
        "EXH" => EXHORTATION,
        "IMPN"=> IMPERATIVE_VERBAL_NOUN,
        "EXL" => EXPLANATION,
        "EQ"  => EQUALIZATION,
        "REM" => RESUMPTION,
        "CAUS"=> CAUSE,
        "AMD" => AMENDMENT,
        "PRO" => PROHIBITION,
        "CIRC"=> CIRCUMSTANTIAL,
        "RSLT"=> RESULT,
        "INT" => INTERPRETATION,
        "COM" => COMITATIVE
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when PartOfSpeech
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

      # Parse the tag to return the corresponding PartOfSpeech object
      def self.parse(tag)
        part_of_speech = TAG_MAP[tag]
        if part_of_speech.nil?
          raise UnsupportedOperationException, "Part of speech tag #{tag} not recognized."
        end

        part_of_speech
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
