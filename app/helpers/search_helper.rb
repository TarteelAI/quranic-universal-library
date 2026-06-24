module SearchHelper
  DISPLAY_SCRIPTS = [
    ['text_qpc_hafs', 'QPC Hafs'],
    ['text_uthmani', 'Uthmani (Me Quran)'],
    ['text_uthmani_simple', 'Uthmani (Simple)'],
    ['text_imlaei', 'Imlaei'],
    ['text_imlaei_simple', 'Imlaei (Without tashkeel)'],
    ['text_indopak', 'Indopak'],
    ['text_indopak_nastaleeq', 'Indopak Nastaleeq'],
    ['text_qpc_nastaleeq', 'QPC Nastaleeq'],
    ['text_qpc_nastaleeq_hafs', 'QPC Nastaleeq Hafs'],
    ['text_digital_khatt', 'Digital Khatt v2'],
    ['text_digital_khatt_v1', 'Digital Khatt v1'],
    ['text_digital_khatt_indopak', 'Digital Khatt Indopak']
  ].freeze

  def search_script_label(script)
    DISPLAY_SCRIPTS.to_h[script] || script
  end

  def highlighted_ayah(text, query, exact:, across: false)
    highlighted = if across
                    Search::Highlighter.highlight_contained(text.to_s, query, exact: exact)
                  else
                    Search::Highlighter.highlight(text.to_s, query, exact: exact)
                  end

    highlighted.html_safe
  end
end
