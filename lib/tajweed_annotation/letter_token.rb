module TajweedAnnotation
  class LetterToken
    attr_reader :letter,
                :diacritics,
                :token_position, # token(with diacritics marks) position
                :char_position, # position within the word
                :word,
                :rules,
                :text

    def initialize(letter_with_diacritics, token_position, char_position, word)
      @text = letter_with_diacritics.join()
      @letter = letter_with_diacritics[0]
      @diacritics = letter_with_diacritics[1..-1]
      @token_position = token_position
      @char_position = char_position
      @word = word
      @rules = {}
    end

    def mark_as_first_letter!
      @token_token_position = 'first'
    end

    def mark_as_last_letter!
      @token_token_position = 'last'
    end

    def first_letter?
      @token_token_position == 'first'
    end

    def last_letter?
      @token_token_position == 'last'
    end

    def process_rules
      return if rules.present?

      if apply_hamza_wasal?
        add_rule(:ham_wasl, 0)
      elsif apply_laam_shamsiyah?
        add_rule(:laam_shamsiyah, 0)
      elsif apply_qalaqah?
        apply_qalaqah_rule
      elsif apply_tanween_or_noon_sakin?
        apply_tanween_or_noon_sakin_rules
      elsif apply_meem_sakin?
        apply_meem_sakin_rules
      elsif apply_ghunnah_rule?
        apply_ghunnah_rule
      elsif apply_tafkheem?
        apply_tafkheem_rule
      elsif apply_slient_rule?
        add_rule(:slnt, 0)
        add_rule(:slnt, 1) if has_harkat? && !has_harkat?(SUPERSCRIPT_ALIF)
      end

      if apply_madda_rule?
        apply_madda_rules
      end
      apply_letter_ra_rule
    end

    def apply_madda_rule?
      apply_madda_normal? || madda_letter? || has_harkat?(ARABIC_MADDAH_ABOVE)
    end

    def apply_madda_normal?
      has_harkat?(SUPERSCRIPT_ALIF) || has_harkat?(SMALL_YAH) || has_harkat?(SMALL_WOW)
    end

    def apply_madda_rules
      next_token = next_letter_token(skip_alif_sukun: true)
      previous_token = previous_letter_token

      if has_harkat?(ARABIC_MADDAH_ABOVE)
        add_rule('madda_necessary', 0)
      elsif next_token&.has_harkat?(HAMZA) || next_token&.letter_hamza?
        if next_token.word == word
          next_token.add_rule('madda_obligatory_mottasel', 0)
          next_token.add_rule('madda_obligatory_mottasel', 1)
        elsif last_letter? && next_token.first_letter?
          add_rule('madda_obligatory_monfasel', 0)
          next_token.add_rule('madda_obligatory_monfasel', 0)
        end
      elsif [letter_alif?, letter_yeh?, letter_wa?].any?
        if (letter_alif? && previous_token.has_harkat?(KASRA)) || (letter_wa? && previous_token.has_harkat?(DAMMA)) || (letter_yeh? && previous_token.has_harkat?(KASRA))
          add_rule('madda_permissible', 0)
        elsif next_token&.has_shaddaa? || next_token&.has_harkat?(SUKUN)
          add_rule('madda_necessary', 0)
        end
      elsif has_harkat?(SUPERSCRIPT_ALIF)
        add_rule(:madda_normal, diacritics.index(SUPERSCRIPT_ALIF) + 1)
      elsif has_harkat?(SMALL_YAH)
        add_rule(:madda_normal, diacritics.index(SMALL_YAH) + 1)
      elsif has_harkat?(SMALL_WOW)
        add_rule(:madda_normal, diacritics.index(SMALL_WOW) + 1)
      end
    end

    def apply_slient_rule?
      alif_sakin = letter_alif? && has_sukun?
      return true if alif_sakin

      if madda_letter?
        if last_letter?
          next_token = next_letter_token(skip_alif_sukun: true)
          next_token&.has_shaddaa? || next_token&.has_sukun?
        elsif letter_wa? # Wow with dagger alif/superscript alif
          has_harkat?(SUPERSCRIPT_ALIF)
        end
      end
    end

    def apply_qalaqah?
      QALAQAH_LETTERS.include?(letter) && has_sukun?
    end

    def apply_qalaqah_rule
      add_rule(:qalaqah, 0)
      add_rule(:qalaqah, 1) if has_harkat?
    end

    def has_harkat?(harkat = nil)
      if harkat
        diacritics.include?(harkat)
      else
        diacritics.present?
      end
    end

    def apply_hamza_wasal?
      letter_hamza_wasal?
    end

    def apply_tanween_or_noon_sakin?
      has_tanween?(include_high_meem: true) || is_non_sukun?
    end

    def apply_ghunnah_rule?
      # Non or meem with shaddaa
      (letter_meem? || letter_non?) && has_shaddaa?
    end

    def apply_ghunnah_rule
      add_rule(:ghunnah, 0)
      diacritics.each_with_index do |_, i|
        add_rule(:ghunnah, i + 1)
      end
    end

    def apply_meem_sakin?
      letter_meem? && (diacritics.blank? || has_sukun?)
    end

    def apply_tanween_or_noon_sakin_rules
      # Izhaar, Idhghaam, Iqlaab or Ikhfa
      # Izhaar: (ا,ح,خ,ع,غ,ه)+(نْ or ـًـٍـٌ)

      next_token = next_letter_token(skip_alif_sukun: false)
      return if next_token.blank?

      if next_token.izhar_letter?
        add_rule('izhar', 0) # Base letter non
        add_rule('izhar', 1) # SUKUN too

        next_token.add_rule('izhar', 0) if next_token.word != word # izhar letter
      elsif next_token.ikhafa_letter?
        add_rule('ikhafa', 0)
        diacritics.each_with_index do |d, i|
          next_token.add_rule('ikhafa', i + 1)
        end
        next_token.add_rule('ikhafa', 0)
        if next_token.has_harkat?
          next_token.diacritics.each_with_index do |d, i|
            next_token.add_rule('ikhafa', i + 1)
          end
        end
      elsif [next_token.letter_meem?, next_token.letter_wa?, next_token.letter_non?, next_token.letter_yeh?].any?
        # Idgham with ghunnah
        # ن,و,ي,م
        add_rule('idgham_ghunnah', 0)
        add_rule('idgham_ghunnah', 1) if has_harkat?
        next_token.add_rule('idgham_ghunnah', 0)

        if next_token.has_harkat?
          next_token.diacritics.each_with_index do |d, i|
            next_token.add_rule('idgham_ghunnah', i + 1)
          end
        end
      elsif [next_token.letter_ra?, next_token.letter_lam?].any?
        # ل, ر
        add_rule('idgham_wo_ghunnah', 0)
        add_rule('idgham_wo_ghunnah', 1) if has_harkat?
        next_token.add_rule('idgham_wo_ghunnah', 0)

        if next_token.has_harkat?
          next_token.diacritics.each_with_index do |d, i|
            next_token.add_rule('idgham_wo_ghunnah', i + 1)
          end
        end
      elsif next_token.letter_ba?
        add_rule('iqlab', 0)
        next_token.add_rule('iqlab', 0)
      end
    end

    def apply_meem_sakin_rules
      # ikhafa_shafawi, idgham_shafawi

      next_token = next_letter_token(skip_alif_sukun: true)

      if next_token&.letter_ba?
        # Meem sakin then Letter ba => ikhafa_shafawi
        add_rule('ikhafa_shafawi', 0)

        if next_token.word != word
          next_token.add_rule('ikhafa_shafawi', 0)

          next_token.diacritics.each_with_index do |d, i|
            next_token.add_rule('ikhafa_shafawi', i + 1)
          end
        end
      elsif next_token&.letter_meem?
        # Meem sakin then Letter meem => idgham_shafawi
        add_rule('idgham_shafawi', 0)
        next_letter_token.add_rule('idgham_shafawi', 0)

        next_token.diacritics.each_with_index do |d, i|
          next_token.add_rule('idgham_shafawi', i + 1)
        end
      else
        # Meem sakin then other letter => izhar_shafawi
        add_rule('izhar_shafawi', 0)
        diacritics.each_with_index do |_, i|
          add_rule('izhar_shafawi', i + 1)
        end
      end
    end

    def apply_laam_shamsiyah?
      if !word.is_allah_word? && starts_with_alif_lam?
        next_letter_token&.samshi_letter?
      end
    end

    def ikhafa_letter?
      # ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك
      [
        letter_kaf?,
        letter_qaf?,
        letter_zah?,
        letter_tah?,
        letter_zaad?,
        letter_sad?,
        letter_sheen?,
        letter_seen?,
        letter_zeh?,
        letter_zal?,
        letter_dal?,
        letter_jeem?,
        letter_sah?,
        letter_teh?,
        letter_feh?].any?
    end

    def is_non_sukun?
      letter.ord == 1606 && (diacritics.empty? || has_sukun?)
    end

    def is_alif_sukun?
      letter_alif? && (has_sukun? || !has_harkat?)
    end

    def is_wow_sukun?
      letter.ord == 1608 && (diacritics.empty? || has_sukun?)
    end

    def has_sukun?
      diacritics.detect do |l|
        l == SUKUN || l.ord == 1618 || l.ord == 1761 # QPC Hafs
      end
    end

    def has_shaddaa?
      diacritics.detect do |l|
        l.ord == 1617
      end
    end

    def madda_letter?
      [letter_yeh?, letter_wa?, letter_alif?].any? || letter.match?(/آ|أ|ؤ|ئ|ء|ى|و|ي/)
    end

    def izhar_letter?
      THROAT_LETTERS.include?(letter) || diacritics.detect do |d|
        THROAT_LETTERS.include?(d) # Check for hamza in diacritics, diacritics.include?(HAMZA) could be faster
      end
    end

    def next_letter_token(skip_alif_sukun: true)
      w = word
      p = token_position
      if last_letter? && word.last_word?
        return nil
      end

      if last_letter?
        w = word.next_word
        p = -1 # we're adding + 1 below, this will make sure we get the first token of the next word
      end

      return if w.blank?
      token = w.letter_tokens[p + 1]

      return if token.blank? || (!skip_alif_sukun && token.is_alif_sukun?)

      if token.last_letter?
        token = w.next_word.letter_tokens[0] if w.next_word
      else
        token = w.letter_tokens[p + 2]
      end

      token
    end

    def previous_letter_token
      word.letter_tokens[token_position - 1]
    end

    def samshi_letter?
      # return true if letter is samshi/sun letter
      SHAMS_LETTERS.include?(letter)
    end

    def apply_tafkheem?
      if HEAVY_LETTERS.include?(letter)
        has_harkat?(FATHA) || has_harkat?(DAMMA) || (has_harkat?(KASRA) && (letter_qaf? || HEAVY_LETTERS_ITBAQ.include?(letter)))
      end
    end

    def apply_letter_ra_rule
      # tafkheem or tarqeeq
      if letter_ra?
        if has_harkat?(FATHA)
          add_rule(:tafkheem, 0)
        elsif has_harkat?(KASRA)
          add_rule(:tarqeeq, 0)
        end
      end
    end

    def apply_tafkheem_rule
      add_rule(:tafkheem, 0)
      diacritics.each_with_index do |_, i|
        add_rule(:tafkheem, 1 + i)
      end
    end

    def has_tanween?(include_high_meem: false)
      tanween = diacritics.detect do |l|
        TANWEEN.include?(l)
      end

      return true if tanween

      if include_high_meem
        return diacritics.include?('ۢ')
      end
    end

    def letter_lam?
      letter == 'ل'
    end

    def letter_alif?
      letter == 'ا'
    end

    def letter_hamza?
      letter == HAMZA
    end

    def letter_ba?
      letter == 'ب'
    end

    def letter_meem?
      letter == 'م'
    end

    def letter_teh?
      letter == 'ت'
    end

    def letter_sah?
      # https://www.compart.com/en/unicode/U+062b
      letter == 'ث'
    end

    def letter_jeem?
      letter == 'ج'
    end

    def letter_dal?
      letter == 'د'
    end

    def letter_zal?
      # https://www.compart.com/en/unicode/U+0630
      letter == 'ذ'
    end

    def letter_ra?
      letter == 'ر'
    end

    def letter_zeh?
      letter == 'ز'
    end

    def letter_seen?
      letter == 'س'
    end

    def letter_sheen?
      letter == 'ش'
    end

    def letter_sad?
      letter == 'ص'
    end

    def letter_zaad?
      # https://www.compart.com/en/unicode/U+0636
      letter == 'ض'
    end

    def letter_tah?
      letter == 'ط'
    end

    def letter_zah?
      letter == 'ظ'
    end

    def letter_feh?
      letter == 'ف'
    end

    def letter_kaf?
      letter == 'ك'
    end

    def letter_qaf?
      letter == 'ق'
    end

    def letter_wa?
      letter == 'و'
    end

    def letter_non?
      letter == 'ن'
    end

    def letter_yeh?
      letter == 'ي'
    end

    def letter_hamza_wasal?
      letter.match?(/ٱ/) || letter.ord == 1649
    end

    def starts_with_alif_lam?
      previous = previous_letter_token
      (letter_lam? && diacritics.blank?) && (previous&.letter_alif? || previous.letter_hamza_wasal?)
    end

    QALAQAH_LETTERS = [
      "ق", "ط", "ب", "ج", "د"
    ]
    # Sun letter
    SHAMS_LETTERS = ['ت', 'ث', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ل', 'ن'].freeze
    # Moon letter
    QAMAR_LETTERS = ['ا', 'ب', 'ج', 'ح', 'خ', 'ع', 'غ', 'ف', 'ق', 'ك', 'م', 'هـ', 'و', 'ي'].freeze
    HEAVY_LETTERS = ['خ', 'ص', 'ض', 'غ', 'ط', 'ق', 'ظ'].freeze
    HEAVY_LETTERS_ITBAQ = ['ص', 'ض', 'ط', 'ظ']

    FATHA = "َ"
    DAMMA = "ُ"
    KASRA = "ِ"
    HAMZA = "ء"

    SUKUN = "ْ" # https://www.compart.com/en/unicode/U+0652
    FATAHAN = "ً" # https://www.compart.com/en/unicode/U+064b
    KASARAN = "ٍ" # https://www.compart.com/en/unicode/U+064d
    DAMMATAN = "ٌ" # https://www.compart.com/en/unicode/U+064c
    ARABIC_INVERTED_DAMMA = "ٗ"
    ARABIC_FATHA_WITH_TWO_DOTS = "ٞ"
    ARABIC_SUBSCRIPT_ALIF = "ٖٖ"
    ARABIC_MADDAH_ABOVE = "ٓ"

    # Izhar
    THROAT_LETTERS = ['أ', 'ء', 'ه', 'ع', 'ح', 'غ', 'خ'].freeze

    TANWEEN = [FATAHAN, KASARAN, DAMMATAN, ARABIC_INVERTED_DAMMA, ARABIC_FATHA_WITH_TWO_DOTS, ARABIC_SUBSCRIPT_ALIF]
    SUPERSCRIPT_ALIF = 'ٰ' # https://www.compart.com/en/unicode/U+0670
    SMALL_YAH = 'ۦ'
    SMALL_WOW = 'ۥ'
    SHADDA = 'ّ'

    protected

    def add_rule(rule, index = 0)
      rule_index = TajweedRules.new('new').index(rule)
      @rules[index] = rule_index
    end
  end
end