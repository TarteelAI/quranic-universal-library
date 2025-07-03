=begin
g = TransliterationGenerator.new('marfia')
g.transliterate("جَآءَتۡهُمۡ")
g.transliterate("مِنۡ أَجۡلِ ذَٰلِكَ كَتَبۡنَا عَلَىٰ بَنِيٓ إِسۡرَٰٓءِيلَ أَنَّهُۥ مَن قَتَلَ نَفۡسَۢا بِغَيۡرِ نَفۡسٍ أَوۡ فَسَادٖ فِي ٱلۡأَرۡضِ فَكَأَنَّمَا قَتَلَ ٱلنَّاسَ جَمِيعٗا وَمَنۡ أَحۡيَاهَا فَكَأَنَّمَآ أَحۡيَا ٱلنَّاسَ جَمِيعٗاۚ وَلَقَدۡ جَآءَتۡهُمۡ رُسُلُنَا بِٱلۡبَيِّنَٰتِ ثُمَّ إِنَّ كَثِيرٗا مِّنۡهُم بَعۡدَ ذَٰلِكَ فِي ٱلۡأَرۡضِ لَمُسۡرِفُونَ")
=end

class TransliterationGenerator
  attr_reader :transliteration_mapping

  def initialize(mapping)
    @transliteration_mapping = mapping
  end

  def transliterate(text)
    mapping = get_mapping
    result = ''
    i = 0

    while i < text.length
      # Check for multi-char match (max 2 chars like 'أَو')
      pair = text[i..i+1]
      if mapping.key?(pair)
        result << mapping[pair]
        i += 2
        next
      end

      char = text[i]
      mapped = mapping[char]

      if mapped == :shadda
        # Double the last consonant (if any)
        last = result[-1]
        result << last if last
      elsif mapped
        result << mapped
      else
        result << char  # fallback: copy as-is
      end

      i += 1
    end

    result
  end

  protected
  def get_mapping
    if transliteration_mapping == 'marfia'
      DAR_UL_MARFIA
    elsif transliteration_mapping == 'simple'
      SIMPLIFIED
    elsif transliteration_mapping == 'tajweed'
      TAJWEED
    else
      raise ArgumentError, "Unknown transliteration mapping: #{transliteration_mapping}"
    end
  end

  HTML = {

  }

  DAR_UL_MARFIA = {
    # Multi-character
    'أَو' => "'aw",
    'وَ' => 'wa',
    'يَا' => 'yâ',

    'ء' => '’',
    'أ' => '’a',
    'ؤ' => '’u',
    'إ' => '’i',
    'ئ' => '’',

    'ا' => 'â',
    'ب' => 'b',
    'ت' => 't',
    'ث' => 'th',
    'ج' => 'j',
    'ح' => 'ḥ',
    'خ' => 'kh',
    'د' => 'd',
    'ذ' => 'ẓ',
    'ر' => 'r',
    'ز' => 'z',
    'س' => 's',
    'ش' => 'sh',
    'ص' => 'ṣ',
    'ض' => 'ḍ',
    'ط' => 'ṭ',
    'ظ' => 'ẓ',
    'ع' => '‘',
    'غ' => 'gh',
    'ف' => 'f',
    'ق' => 'q',
    'ك' => 'k',
    'ل' => 'l',
    'م' => 'm',
    'ن' => 'n',
    'ه' => 'h',
    'و' => 'ou',
    'ى' => 'â',  # alif maskhura
    'ي' => 'ee',
    'ة' => 'h',
    'ٱ' => '',   # hamzat wasla

    # Harakat
    'َ' => 'a',
    'ُ' => 'u',
    'ِ' => 'i',
    'ً' => 'an',
    'ٌ' => 'un',
    'ٍ' => 'in',
    'ْ' => '',   # sukon
    'ّ' => :shadda,  # repeat this letter
    'ٰ' => 'â',  # dagger alif

    # Silent chars
    'ٓ' => '', 'ۖ' => '', 'ۗ' => '', 'ۘ' => '', 'ۚ' => '',
    'ۛ' => '', 'ۜ' => '', '۠' => '', 'ۡ' => '', 'ۢ' => '',
    'ۤ' => '', 'ۥ' => '', 'ۦ' => '', 'ۧ' => '', 'ۨ' => '',
    '۩' => '', '۪' => '', '۬' => '', 'ۭ' => ''
  }

  TAJWEED = {
    'ا' => 'ā', 'أ' => 'a', 'إ' => 'i', 'آ' => 'ā',
    'ب' => 'b', 'ت' => 't', 'ث' => 'th',
    'ج' => 'j', 'ح' => 'ḥ', 'خ' => 'kh',
    'د' => 'd', 'ذ' => 'dh',
    'ر' => 'r', 'ز' => 'z',
    'س' => 's', 'ش' => 'sh',
    'ص' => 'ṣ', 'ض' => 'ḍ', 'ط' => 'ṭ', 'ظ' => 'ẓ',
    'ع' => 'ʿ', 'غ' => 'gh',
    'ف' => 'f', 'ق' => 'q', 'ك' => 'k',
    'ل' => 'l', 'م' => 'm', 'ن' => 'n',
    'ه' => 'h', 'و' => 'w', 'ي' => 'y',
    'ء' => 'ʾ', 'ى' => 'ā', 'ئ' => 'ʾ', 'ؤ' => 'ʾ',
    'ً' => 'an', 'ٌ' => 'un', 'ٍ' => 'in',
    'َ' => 'a', 'ُ' => 'u', 'ِ' => 'i',
    'ّ' => :shadda, 'ْ' => '', 'ٰ' => 'ā',
    ' ' => ' '
  }

  SIMPLIFIED = {
    'ا' => 'a', 'أ' => 'a', 'إ' => 'i', 'آ' => 'aa',
    'ب' => 'b', 'ت' => 't', 'ث' => 'th',
    'ج' => 'j', 'ح' => 'h', 'خ' => 'kh',
    'د' => 'd', 'ذ' => 'dh',
    'ر' => 'r', 'ز' => 'z',
    'س' => 's', 'ش' => 'sh',
    'ص' => 's', 'ض' => 'd', 'ط' => 't', 'ظ' => 'z',
    'ع' => '‘', 'غ' => 'gh',
    'ف' => 'f', 'ق' => 'q', 'ك' => 'k',
    'ل' => 'l', 'م' => 'm', 'ن' => 'n',
    'ه' => 'h', 'و' => 'w', 'ي' => 'y',
    'ء' => "'", 'ى' => 'a', 'ئ' => "'", 'ؤ' => "'",
    'ً' => 'an', 'ٌ' => 'un', 'ٍ' => 'in',
    'َ' => 'a', 'ُ' => 'u', 'ِ' => 'i',
    'ّ' => :shadda, 'ْ' => '', 'ٰ' => 'a',
    ' ' => ' '
  }
end
