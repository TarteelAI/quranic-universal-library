module TajweedAnnotation
  class LetterToken
    attr_reader :letter,
                :diacritics,
                :position,
                :word,
                :rules,
                :text

    def initialize(letter_with_diacritics, position, word)
      @text = letter_with_diacritics.join()
      @letter = letter_with_diacritics[0]
      @diacritics = letter_with_diacritics[1..-1]
      @position = position
      @word = word
      @rules = {}
    end

    def mark_as_first_letter!
      @token_position = 'first'
    end

    def mark_as_last_letter!
      @token_position = 'last'
    end

    def first_letter?
      @token_position == 'first'
    end

    def last_letter?
      @token_position == 'last'
    end

    def process_rules
      return if rules.present?

      if apply_hamza_wasal?
        add_rule(:ham_wasl, 0)
      elsif apply_laam_shamsiyah?
        add_rule(:laam_shamsiyah, 0)
      elsif apply_slient_rule?
        add_rule(:slnt, 0)
        add_rule(:slnt, 1)
      elsif apply_tanween_or_noon_sakin?
        apply_tanween_or_noon_sakin_rules
      end
    end

    def apply_slient_rule?
      is_alif_sukun? || is_wow_sukun?
    end

    def apply_hamza_wasal?
      letter_hamza_wasal?
    end

    def apply_tanween_or_noon_sakin?
      has_tanween? || is_non_sukun?
    end

    def apply_tanween_or_noon_sakin_rules
      # Izhaar, Idhghaam, Iqlaab or Ikhfa
      next_token = next_letter_token(skip_alif_sukun: false)

      if next_token.izhar_letter?
        add_rule('izhar', 0) # Base letter non
        add_rule('izhar', 1) # SUKUN too

        next_token.add_rule('izhar', 0) # izhar letter
      end
    end

    def apply_laam_shamsiyah?
      if !word.is_allah_word? && starts_with_alif_lam?
        next_letter_token&.samshi_letter?
      end
    end

    def is_non_sukun?
      letter.ord == 1606 && (diacritics.empty? || has_sukun?)
    end

    def is_alif_sukun?
      letter.ord == 1575 && (diacritics.empty? || has_sukun?)
    end

    def is_wow_sukun?
      letter.ord == 1608 && (diacritics.empty? || has_sukun?)
    end

    def has_sukun?
      diacritics.detect do |l|
        l == SUKUN || l.ord == 1618 || l.ord == 1761 # QPC Hafs
      end
    end

    def madda_letter?
      letter.match?(/آ|أ|ؤ|ئ|ء|ى/)
    end

    def izhar_letter?
      THROAT_LETTERS.include?(letter) || diacritics.detect do |d|
        THROAT_LETTERS.include?(d) # Check for hamza in diacritics, diacritics.include?(HAMZA) could be faster
      end
    end

    def next_letter_token(skip_alif_sukun: true)
      w = word
      p = position

      if last_letter?
        w = word.next_word
        p = -1 # we're adding + 1 below, this will make sure we get the first token of the next word
      end

      token = w.letter_tokens[p + 1]

      if token.blank? || (!skip_alif_sukun && token.is_alif_sukun?)
        if token.last_letter?
          token = w.next_word.letter_tokens[0]
        else
          token = w.letter_tokens[p + 2]
        end
      end

      token
    end

    def previous_letter_token
      word.letter_tokens[position - 1]
    end

    def samshi_letter?
      # return true if letter is samshi/sun letter
      SHAMS_LETTERS.include?(letter)
    end

    def has_tanween?
      diacritics.detect do |l|
        TANWEEN.include?(l)
      end
    end

    def letter_lam?
      letter == 'ل'
    end

    def letter_alif?
      letter == 'ا'
    end

    def letter_hamza_wasal?
      letter.match?(/ٱ/) || letter.ord == 1649
    end

    def starts_with_alif_lam?
      previous = previous_letter_token
      (letter_lam? && diacritics.blank?) && (previous&.letter_alif? || previous.letter_hamza_wasal?)
    end

    # Sun letter
    SHAMS_LETTERS = ['ت', 'ث', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ل', 'ن'].freeze
    # Moon letter
    QAMAR_LETTERS = ['ا', 'ب', 'ج', 'ح', 'خ', 'ع', 'غ', 'ف', 'ق', 'ك', 'م', 'هـ', 'و', 'ي'].freeze

    SUKUN = "ْ" # https://www.compart.com/en/unicode/U+0652
    FATAHAN = "ً" # https://www.compart.com/en/unicode/U+064b
    KASARAN = "ٍ" # https://www.compart.com/en/unicode/U+064d
    DAMMATAN = "ٌ" # https://www.compart.com/en/unicode/U+064c

    # Izhar
    THROAT_LETTERS = ['أ', 'ء', 'ه', 'ع', 'ح', 'غ', 'خ']

    TANWEEN = [FATAHAN, KASARAN, DAMMATAN]

    protected

    def add_rule(rule, index = 0)
      rule_index = TajweedRules.new('new').index(rule)
      @rules[index] = rule_index
    end
  end
end