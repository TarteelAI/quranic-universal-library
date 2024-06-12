class WordsUtil
  #HAFS_WAQF = ["ـ", "ۖ", "ۗ", "ۘ", "ۚ", "ۛ", "ۜ", "۞", "ۢ", "ۦ", "ۧ", "ۨ", "۩", "۪", "۬", "ۭ"]
  #REMOVE_WAQF_REG = Regexp.new(HAFS_WAQF.join('|'))

  HAFS_WAQF_FOR_PHRASE = ["ۖ", "ۗ", "ۚ", "ۚ", "ۜ", "ۢ", "ۨ", "ۭ"]
  HAFS_WAQF_WITH_SIGNS = ["ـ", "ۖ", "ۗ", "ۘ", "ۚ", "ۛ", "ۜ", "۞", "ۢ", "ۦ", "ۧ", "ۨ", "۩", "۪", "۬", "ۭ"]
  INDOPAK_WAQF = ["ۛ", "ٚ", "ؔ", "ؕ", "ۥ", "ۚ", "۪", "۠", "ۙ", "ؗ", "۫", "ۘ", "ۗ", "۬", "ۙ", "۬", "ۦ"]
  EXTRA_CHARS = ['', '', '', '', '‏', ',', '‏', '​', '', '‏', "\u200f"]
  WAQF_REG = Regexp.new((HAFS_WAQF_WITH_SIGNS + INDOPAK_WAQF + EXTRA_CHARS).join('|'))

  def uniq_in_chapter(chapter_id, script: 'text_imlaei_simple')
    unique_words = clean_words Word.unscoped.words.where(chapter_id: chapter_id).order('verse_id ASC, position asc').pluck(script)
    other_chapter_words = clean_words Word.words.where.not(chapter_id: chapter_id).pluck(script)
    unique_words - other_chapter_words
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
       .remove_dialectic(replace_hamza: false)
       .strip
    end

    words.uniq
  end
end