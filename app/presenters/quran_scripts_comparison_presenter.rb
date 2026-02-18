class QuranScriptsComparisonPresenter < ApplicationPresenter
  MADANI_SCRIPTS = [
    'text_qpc_hafs',
    'text_uthmani',
    'text_digital_khatt',
    'text_digital_khatt_v1'
  ].freeze

  INDOPAK_SCRIPTS = [
    'text_digital_khatt_indopak',
    'text_qpc_nastaleeq_hafs',
    'text_indopak',
    'text_indopak_nastaleeq'
  ].freeze

  SCRIPT_DISPLAY_NAMES = {
    'text_qpc_hafs' => 'QPC Hafs',
    'text_digital_khatt' => 'Digital Khatt v2',
    'text_digital_khatt_v1' => 'Digital Khatt v1',
    'text_digital_khatt_indopak' => 'Digital Khatt Indopak',
    'text_indopak_nastaleeq' => 'Indopak Nastaleeq',
    'text_qpc_nastaleeq_hafs' => 'QPC Nastaleeq Hafs',
    'code_v4' => 'V4 Tajweed',
    'code_v1' => 'QPC V1',
    'code_v2' => 'QPC V2',
    'uthmani' => 'Uthmani',
    'text_uthmani' => 'Uthmani',
    'text_indopak' => 'Indopak',
  }.freeze

  def script_type_selected?
    params[:script_type].present?
  end

  def script_type
    @script_type ||= begin
      type = params[:script_type].to_s.strip.downcase
      ['madani', 'indopak'].include?(type) ? type : 'madani'
    end
  end

  def show_madani_script_comparision?
    script_type == 'madani'
  end

  def comparision_scripts
    if show_madani_script_comparision?
      [
        # scripts with v2 waqfs
        'text_qpc_hafs',
        'code_v2',
        'text_digital_khatt',

        # scripts with v1 waqfs
        'text_uthmani',
        'code_v1',
        'text_digital_khatt_v1',
        'code_v4'
      ]
    else
      INDOPAK_SCRIPTS
    end
  end

  def scripts
    @scripts ||= script_type == 'madani' ? MADANI_SCRIPTS : INDOPAK_SCRIPTS
  end

  def char
    @char ||= params[:char].to_s.strip
  end

  def charsets
    return @charsets if @charsets.present?
    
    @charsets = {}
    return @charsets if char.present?

    scripts.each do |script_name|
      table = Verse.arel_table
      charset = Verse.unscoped
                    .where(table[script_name].not_eq(nil))
                    .where(table[script_name].not_eq(''))
                    .pluck(script_name)
                    .join
                    .chars
                    .uniq
                    .sort
      @charsets[script_name] = charset
    end

    @charsets
  end

  def words
    return [] if char.blank?
    return @words if @words.present?

    @words = []

    script = params[:script].to_s.strip
    script = scripts.first if script.blank? || !scripts.include?(script)

    pattern = "%#{char}%"
    order = params[:sort_order] == 'desc' ? 'desc' : 'asc'

    words_query = Word.unscoped
                      .where("#{script} LIKE ?", pattern)
                      .order("word_index #{order}")
    
    @words = paginate(words_query, items: 100)
  end

  def script_display_name(script_name)
    SCRIPT_DISPLAY_NAMES[script_name] || script_name
  end

  def review_words
    return [] if char.blank? || words.blank?

    @review_words ||= words.select do |word|
      !scripts.all? { |script| word.send(script).to_s.include?(char) }
    end.map(&:location)
  end

  def meta_title
    if char.present?
      "Quran Scripts Comparison - Words containing '#{char}'"
    elsif params[:script_type].present?
      "Quran Scripts Comparison - #{script_type.capitalize} Script Character Selection"
    else
      "Quran Scripts Comparison"
    end
  end

  def meta_description
    "Compare different Quranic script variants (Madani and Indopak) to identify inconsistencies and missing characters. Essential for script proofreading and quality assurance."
  end

  def meta_keywords
    'Quran script comparison, script variants, Madani script, Indopak script, Quran font compatibility, script proofreading'
  end
end

