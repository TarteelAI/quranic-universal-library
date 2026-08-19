module QuranScriptHelper
  def get_quran_script_font_family(script, verse)
    case script.to_s
    when 'code_v1'
      "p#{verse.page_number}-v1"
    when 'code_v2'
      "p#{verse.v2_page}-v2"
    when 'code_v4'
      "p#{verse.v2_page}-v4-tajweed"
    when 'text_qpc_hafs'
      'qpc-hafs'
    when 'text_qpc_hafs_tajweed'
      'qpc-hafs-color'
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
    when 'text_uthmani_simple'
      'me_quran'
    when 'text_imlaei', 'text_imlaei_simple'
      'qpc-hafs'
    when 'text_indopak'
      'indopak'
    else
      script
    end
  end
end