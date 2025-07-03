class WordsUtil
  #HAFS_WAQF = ["ـ", "ۖ", "ۗ", "ۘ", "ۚ", "ۛ", "ۜ", "۞", "ۢ", "ۦ", "ۧ", "ۨ", "۩", "۪", "۬", "ۭ"]
  #REMOVE_WAQF_REG = Regexp.new(HAFS_WAQF.join('|'))

  HAFS_WAQF_FOR_PHRASE = ["ۖ", "ۗ", "ۚ", "ۚ", "ۜ", "ۢ", "ۨ", "ۭ"]
  HAFS_WAQF_WITH_SIGNS = ["ـ", "ۖ", "ۗ", "ۘ", "ۚ", "ۛ", "ۜ", "۞", "ۢ", "ۦ", "ۧ", "ۨ", "۩", "۪", "۬", "ۭ"]
  INDOPAK_WAQF = ["ۛ", "ٚ", "ؔ", "ؕ", "ۥ", "ۚ", "۪", "۠", "ۙ", "ؗ", "۫", "ۘ", "ۗ", "۬", "ۙ", "۬", "ۦ"]
  EXTRA_CHARS = ['', '', '', '', '‏', ',', '‏', '​', '', '‏', "\u200f"]
  WAQF_REG = Regexp.new((HAFS_WAQF_WITH_SIGNS + INDOPAK_WAQF + EXTRA_CHARS).join('|'))
  QPC_DIACRITIC_MARKS = [
    "ِ", # https://www.compart.com/en/unicode/U+0650 - ARABIC KASRA
    "ۡ", # https://www.compart.com/en/unicode/U+06e1 - ARABIC SMALL HIGH DOTLESS HEAD OF KHAH
    "ّ", # https://www.compart.com/en/unicode/U+0651 - ARABIC SHADDA
    "َ", # https://www.compart.com/en/unicode/U+064E - ARABIC FATHA
    "ٰ", # https://www.compart.com/en/unicode/U+0670 - ARABIC LETTER SUPERSCRIPT ALEF
    " ", # https://www.compart.com/en/unicode/U+00a0 - NBSP
    "ُ", # https://www.compart.com/en/unicode/U+064f - Arabic Damma
    "ٓ", # https://www.compart.com/en/unicode/U+0653
    "ۛ", # https://www.compart.com/en/unicode/U+06db
    "ٗ", # https://www.compart.com/en/unicode/U+0657
    "ْ", # https://www.compart.com/en/unicode/U+0652
    "ۖ", # https://www.compart.com/en/unicode/U+06d6
    "ٌ", # https://www.compart.com/en/unicode/U+064c
    "ٞ", # https://www.compart.com/en/unicode/U+065e
    "ۢ", # https://www.compart.com/en/unicode/U+06e2
    "٠", # https://www.compart.com/en/unicode/U+0660
    "ۗ", # https://www.compart.com/en/unicode/U+06d7
    "ۥ",  # https://www.compart.com/en/unicode/U+06e5
    "ٖ", # https://www.compart.com/en/unicode/U+0656
    "ۚ", # https://www.compart.com/en/unicode/U+06da
    "ۦ", # https://www.compart.com/en/unicode/U+06e6
    "۞", # https://www.compart.com/en/unicode/U+06de
    "ۘ", # https://www.compart.com/en/unicode/U+06d8
    "ٍ", # https://www.compart.com/en/unicode/U+064d
    "ـ", # https://www.compart.com/en/unicode/U+0640
    "ٔ", # https://www.compart.com/en/unicode/U+0654
    "ً", # https://www.compart.com/en/unicode/U+064b
    "ۭ", # https://www.compart.com/en/unicode/U+06e7
    "ۧ", # https://www.compart.com/en/unicode/U+06e7
    "ۜ", # https://www.compart.com/en/unicode/U+06dc
    "۠", # https://www.compart.com/en/unicode/U+06e0
    "ۤ", # https://www.compart.com/en/unicode/U+06e4
    "۩", # https://www.compart.com/en/unicode/U+06e9
    "ٕ", # https://www.compart.com/en/unicode/U+0655
    "۪", # https://www.compart.com/en/unicode/U+06ea
    "۬", # https://www.compart.com/en/unicode/U+06ec
    "ۨ", # https://www.compart.com/en/unicode/U+06e8
  ]

  def uniq_in_chapter(chapter_id, script: 'text_imlaei_simple')
    unique_words = clean_words Word.unscoped.words.where(chapter_id: chapter_id).order('verse_id ASC, position asc').pluck(script)
    other_chapter_words = clean_words Word.words.where.not(chapter_id: chapter_id).pluck(script)
    unique_words - other_chapter_words
  end

  ARABIC_LETTERS = [
    "ٱ", # https://www.compart.com/en/unicode/U+0671 - ARABIC LETTER ALEF WASLA
    "إ", # https://www.compart.com/en/unicode/U+0625
    "أ", # https://www.compart.com/en/unicode/U+0623
  ]

  # Split the word into an array where each letter and its following diacritic marks are grouped together
  def split_chars_with_tashkeel(word)
    groups = []
    current_group = []

    word.chars.each do |char|
      if QPC_DIACRITIC_MARKS.include?(char) || char.ord == 32
        current_group << char
      else
        groups << current_group unless current_group.empty?
        current_group = []
        current_group << char
      end
    end

    groups << current_group unless current_group.empty?

    groups
  end

  def split_by_hafs_waqf(text)
    text.split Regexp.new(HAFS_WAQF_FOR_PHRASE.join('|'))
  end

  def remove_waqf(text)
    text.to_s.gsub(WAQF_REG, '').gsub(160.chr("UTF-8"),'')
  end

  def clean_words(list)
    words = list.map do |w|
      w.sub(WAQF_REG, '')
       .remove_diacritics(replace_hamza: false)
       .strip
    end

    words.uniq
  end
end