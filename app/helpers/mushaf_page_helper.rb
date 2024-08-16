module MushafPageHelper
  def all_quran_fonts
    [
      ['indopak hahafi', 'mushaf-indopak-nastaleeq-hanafi-compressed'],
      ['QPC Nastaleeq', 'mushaf-qpc-nastaleeq'],
      ['al Qalam', 'mushaf-al_qalam'],
      ['QPC Hafs', 'qpc-hafs'],
      ['Me Quran', 'me_quran']
    ]
  end

  def mushaf_font_options(mushaf)
    font = mushaf.default_font_name

    if font.include?('indopak-nastaleeq') || font.include?('hanafi')
      [
        ['Normal', 'indopak-nastaleeq-hanafi-normal'],
        ['Compact', 'indopak-nastaleeq-hanafi-compact'],
        ['Compressed', 'indopak-nastaleeq-hanafi-compressed'],
        ['QPC Nastaleeq', 'qpc-nastaleeq'],
        ['al Qalam', 'al_qalam'],
      ]
    elsif font.include?('madinah')
      [
        ['Normal', 'indopak-nastaleeq-madinah-normal'],
        ['Compact', 'indopak-nastaleeq-madinah-compact'],
        ['Compressed', 'indopak-nastaleeq-madinah-compressed'],
        ['QPC Nastaleeq', 'qpc-nastaleeq'],
        ['al Qalam', 'al_qalam'],
      ]
    else
      []
    end
  end

  def group_words_lines(words)
    lines = {}

    words.each do |w|
      lines[w.line_number] ||= {}
      lines[w.line_number][w.verse_id] ||= []

      lines[w.line_number][w.verse_id] << w
    end

    lines
  end
end

