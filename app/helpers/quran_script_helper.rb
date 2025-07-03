module QuranScriptHelper
  def get_quran_script_font_family(script, verse)
    case script.to_s
    when 'code_v1'
      "p#{verse.page_number}-v1"
    when 'code_v2'
      "p#{verse.page_number}-v2"
    when 'code_v4'
      "p#{verse.v2_page}-v4-tajweed"
    when 'text_qpc_hafs'
      'qpc-hafs'
    when 'text_uthmani_tajweed'
      'tajweed-new qpc-hafs'
    when 'text_qpc_nastaleeq', 'text_qpc_nastaleeq_hafs'
      'qpc-nastaleeq'
    when 'text_indopak_nastaleeq'
      'indopak-nastaleeq'
    when 'text_digital_khatt'
      'digitalkhatt-v2'
    when 'text_digital_khatt_v1'
      'digitalkhatt'
    when 'text_digital_khatt_indopak'
      'digitalkhatt-indopak'
    when 'text_uthmani'
      'me_quran'
    when 'text_indopak'
      'indopak'
    end
  end

  def find_common_verses_words(verses)
    word_sets = verses.map do |v|
      v.words.map do |w|
        w.text_qpc_hafs.split(' ').map(&:remove_diacritics)
      end
    end

    common = word_sets.flatten.group_by(&:itself).select { |_w, list| list.size > 1 }.keys
    common.to_set
  end
end