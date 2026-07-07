require 'ostruct'

module Corpus
  module Morphology
    # Verb form (وزن): Arabic builds verbs by pouring a (usually 3-letter) root
    # into one of these numbered patterns; each pattern adds its own shade of
    # meaning to the root. Patterns shown with the placeholder root ف-ع-ل.
    # I — فَعَلَ — the basic form: كَتَبَ "he wrote".
    # II — فَعَّلَ — intensive or causative: نَزَّلَ "he sent down (in stages)".
    # III — فَاعَلَ — action directed at someone: قَاتَلَ "he fought (someone)".
    # IV — أَفْعَلَ — causative: أَنزَلَ "he sent down".
    # V — تَفَعَّلَ — reflexive of II: تَوَكَّلَ "he put his trust (in)".
    # VI — تَفَاعَلَ — mutual action: تَعَاوَنَ "they helped one another".
    # VII — انْفَعَلَ — undergoing/result: انفَجَرَ "it gushed forth".
    # VIII — افْتَعَلَ — reflexive: اتَّقَىٰ "he was mindful (of God)".
    # IX — افْعَلَّ — colors and defects: ابْيَضَّ "it turned white".
    # X — اسْتَفْعَلَ — seeking or asking for: اسْتَغْفَرَ "he sought forgiveness".
    # XI — افْعَالَّ — rare, intensified IX: اسْوَادَّ "it turned deep black".
    # XII — افْعَوْعَلَ — rare intensive: اعْشَوْشَبَ "it became lush with growth".

    class FormType < OpenStruct
      FIRST   = new(tag: "I")
      SECOND  = new(tag: "II")
      THIRD   = new(tag: "III")
      FOURTH  = new(tag: "IV")
      FIFTH   = new(tag: "V")
      SIXTH   = new(tag: "VI")
      SEVENTH = new(tag: "VII")
      EIGHTH  = new(tag: "VIII")
      NINTH   = new(tag: "IX")
      TENTH   = new(tag: "X")
      ELEVENTH = new(tag: "XI")
      TWELFTH = new(tag: "XII")

      TAG_MAP = {
        "I"    => FIRST,
        "II"   => SECOND,
        "III"  => THIRD,
        "IV"   => FOURTH,
        "V"    => FIFTH,
        "VI"   => SIXTH,
        "VII"  => SEVENTH,
        "VIII" => EIGHTH,
        "IX"   => NINTH,
        "X"    => TENTH,
        "XI"   => ELEVENTH,
        "XII"  => TWELFTH
      }

      def to_s
        tag
      end

      def ==(other)
        case other
        when FormType
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
        TAG_MAP[tag] || raise(UnsupportedOperationException, "FormType tag #{tag} not recognized.")
      end

      def self.all
        TAG_MAP.values
      end
    end
  end
end
