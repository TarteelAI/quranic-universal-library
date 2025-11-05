module MushafPageHelper
  def all_quran_fonts
    [
      ['Indopak nastaleeq', 'indopak-nastaleeq'],
      ['QPC Nastaleeq', 'qpc-nastaleeq'],
      ['Al Qalam', 'mushaf-al_qalam'],
      ['QPC Hafs', 'qpc-hafs'],
      ['QPC Hafs color', 'qpc-hafs-color'],
      ['QPC Dotted', 'qpc-dotted'],
      ['QPC Outline', 'qpc-outline'],
      ['Me Quran', 'me_quran'],
      ['Digital Khatt', 'digitalkhatt'],
      ['Digital Khatt Indopak', 'digitalkhatt-indopak'],
      ['Urdu', 'urdu'],
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
        ['al Qalam', 'al_qalam']
      ]
    elsif font.include?('madinah')
      [
        ['Normal', 'indopak-nastaleeq-madinah-normal'],
        ['Compact', 'indopak-nastaleeq-madinah-compact'],
        ['Compressed', 'indopak-nastaleeq-madinah-compressed'],
        ['QPC Nastaleeq', 'qpc-nastaleeq'],
        ['al Qalam', 'al_qalam'],
        ['Digital Khatt', 'digitalkhatt']
      ]
    elsif font.include? 'qpc-hafs'
      [
        ['QPC Hafs', 'qpc-hafs'],
        ['QPC Hafs color', 'qpc-hafs-color']
      ]
    else
      []
    end
  end

  def group_words_lines(words)
    lines = {}

    words.includes(:word).each do |w|
      lines[w.line_number] ||= {}
      lines[w.line_number][w.verse_id] ||= []

      lines[w.line_number][w.verse_id] << w
    end

    lines
  end

  def valid_mushaf_view_type?(type)
    ['page_mapping', 'line_alignment', 'proofreading', 'compare'].include?(type)
  end

  def page_status(page)
    return 'Set Ayah range' if page.first_verse_id.nil? || page.last_verse_id.nil?
    
    words_count = @words_counts&.[](page.page_number) || 0
    return 'Map words needed' if words_count == 0
    
    lines_count = @lines_counts&.[](page.page_number) || 0
    return 'Align lines needed' if lines_count == 0
    
    'Ready'
  end

  def status_badge_class(status)
    case status
    when 'Ready'
      'tw-bg-green-100 tw-text-green-800'
    when 'Align lines needed'
      'tw-bg-yellow-100 tw-text-yellow-800'
    when 'Map words needed'
      'tw-bg-orange-100 tw-text-orange-800'
    when 'Set Ayah range'
      'tw-bg-red-100 tw-text-red-800'
    else
      'tw-bg-gray-100 tw-text-gray-800'
    end
  end

  def sort_order_link(text, sort_key, url_params = {}, link_options = {})
    order = params[:sort_order] == 'desc' ? 'asc' : 'desc'

    icon_asc = "<i class='fa fa-sort-up #{'active' if params[:sort_order] == 'asc' && params[:sort_key] == sort_key.to_s}'></i>"
    icon_desc = "<i class='fa fa-sort-down #{'active' if params[:sort_order] == 'desc' && params[:sort_key] == sort_key.to_s}'></i>"

    url_params.merge!(
      sort_key: sort_key,
      sort_order: order,
      search: params[:search]
    )

    link_options[:class] = "d-flex sort-link #{link_options[:class]}"

    link_to url_for(url_params), link_options do
      "<span class='label-text tw-me-2'>#{text}</span> <span class='sort-icons'>#{icon_asc} #{icon_desc}</span>".html_safe
    end
  end
end

