module Corpus
  module Morphology
    # Part of speech: what kind of word a token is. Classical Arabic divides
    # all words into noun (اسم), verb (فعل) and particle (حرف); this tagset
    # refines that into 45 tags, most of them naming a specific particle type.
    class PartOfSpeech < OpenStruct
      NOUN                    = new(tag: "N")    # noun, اسم: كِتَاب "book"
      PROPER_NOUN             = new(tag: "PN")   # proper noun, اسم علم: اللَّه، مُوسَىٰ
      PRONOUN                 = new(tag: "PRON") # pronoun, ضمير: هُوَ "he"
      DEMONSTRATIVE           = new(tag: "DEM")  # demonstrative, اسم إشارة: ذَٰلِكَ "that"
      RELATIVE                = new(tag: "REL")  # relative pronoun, اسم موصول: الَّذِي "which/who"
      ADJECTIVE               = new(tag: "ADJ")  # adjective, صفة: الرَّحِيم "the Merciful"
      VERB                    = new(tag: "V")    # verb, فعل: قَالَ "he said"
      PREPOSITION             = new(tag: "P")    # preposition, حرف جر: فِي "in", بِ "with"
      INTERROGATIVE           = new(tag: "INTG") # question particle, حرف استفهام: هَلْ
      VOCATIVE                = new(tag: "VOC")  # calling particle, حرف نداء: يَا "O …"
      NEGATIVE                = new(tag: "NEG")  # negation particle, حرف نفي: لَا، مَا "not"
      EMPHATIC                = new(tag: "EMPH") # emphasis lam, لام التوكيد: لَ "surely"
      PURPOSE                 = new(tag: "PRP")  # purpose lam, لام التعليل: لِ "in order to"
      IMPERATIVE              = new(tag: "IMPV") # command lam, لام الأمر: لِ in فَلْيَعْبُدُوا "so let them worship"
      FUTURE                  = new(tag: "FUT")  # future particle, حرف استقبال: سَ in سَيَقُولُ "he will say"
      CONJUNCTION             = new(tag: "CONJ") # joining particle, حرف عطف: وَ "and"
      DETERMINER              = new(tag: "DET")  # the definite article, أداة التعريف: ٱل "the"
      INITIALS                = new(tag: "INL")  # disconnected opening letters, حروف مقطعة: الٓمٓ
      TIME                    = new(tag: "T")    # time adverb, ظرف زمان: إِذْ "when"
      LOCATION                = new(tag: "LOC")  # place adverb, ظرف مكان: عِندَ "at/with"
      ACCUSATIVE              = new(tag: "ACC")  # accusative particle, حرف نصب: إِنَّ "indeed"
      CONDITIONAL             = new(tag: "COND") # condition particle, حرف شرط: إِن "if"
      SUBORDINATING_CONJUNCTION = new(tag: "SUB") # clause opener, حرف مصدري: أَن "that"
      RESTRICTION             = new(tag: "RES")  # restriction particle, أداة حصر: إِنَّمَا "only"
      EXCEPTIVE               = new(tag: "EXP")  # exception particle, أداة استثناء: إِلَّا "except"
      AVERSION                = new(tag: "AVR")  # rebuke particle, حرف ردع: كَلَّا "nay!"
      CERTAINTY               = new(tag: "CERT") # certainty particle, حرف تحقيق: قَدْ "certainly"
      RETRACTION              = new(tag: "RET")  # correction particle, حرف إضراب: بَلْ "rather"
      PREVENTIVE              = new(tag: "PREV") # blocking مَا, ما الكافة: the مَا in إِنَّمَا
      ANSWER                  = new(tag: "ANS")  # answer particle, حرف جواب: بَلَىٰ، نَعَمْ "yes indeed"
      INCEPTIVE               = new(tag: "INC")  # opening particle, حرف ابتداء: أَلَا "unquestionably"
      SURPRISE                = new(tag: "SUR")  # sudden-event إذا, إذا الفجائية: "then behold …"
      SUPPLEMENTAL            = new(tag: "SUP")  # extra/redundant particle, حرف زائد: مَا in فَبِمَا رَحْمَةٍ
      EXHORTATION             = new(tag: "EXH")  # urging particle, حرف تحضيض: لَوْلَا "why do you not …"
      IMPERATIVE_VERBAL_NOUN  = new(tag: "IMPN") # noun acting as a command, اسم فعل أمر: هَلُمَّ "come!"
      EXPLANATION             = new(tag: "EXL")  # detailing particle, حرف تفصيل: أَمَّا "as for …"
      EQUALIZATION            = new(tag: "EQ")   # equalizing hamza, حرف تسوية: أ in سَوَاءٌ عَلَيْهِمْ أَأَنذَرْتَهُمْ
      RESUMPTION              = new(tag: "REM")  # topic-restarting وَ/فَ, حرف استئناف
      CAUSE                   = new(tag: "CAUS") # cause fa, فاء السببية: فَ "so that"
      AMENDMENT               = new(tag: "AMD")  # "but/however", حرف استدراك: لَٰكِنْ
      PROHIBITION             = new(tag: "PRO")  # forbidding لا, لا الناهية: لَا in لَا تَخَفْ "fear not"
      CIRCUMSTANTIAL          = new(tag: "CIRC") # state-describing وَ, واو الحال: "while …"
      RESULT                  = new(tag: "RSLT") # condition-result fa, فاء جواب الشرط: فَ "then"
      INTERPRETATION          = new(tag: "INT")  # clarifying particle, حرف تفسير: أَيْ، أَن "that is …"
      COMITATIVE              = new(tag: "COM")  # accompaniment وَ, واو المعية: "along with"

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
