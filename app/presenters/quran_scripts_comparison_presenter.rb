# The scripts comparison tool, on scripts rows since P7.2.
#
# Three modes behind one page:
#   - madani / indopak: the character audit QUL had — every character used by
#     the family's unicode scripts, and the words carrying one character across
#     the family's scripts (lists come from Script meta_data family and
#     compare_position / charset_position, seeded by rake qiraat:seed:scripts)
#   - riwayah: any two scripts with text (column- or row-backed) side by side
#     for one surah, with the words of word_differences whose spelling groups
#     separate the two riwayat
class QuranScriptsComparisonPresenter < ApplicationPresenter
  SCRIPT_TYPES = %w[madani indopak riwayah].freeze
  AYAHS_PER_PAGE = 20

  def script_type_selected?
    params[:script_type].present?
  end

  def script_type
    @script_type ||= begin
      type = params[:script_type].to_s.strip.downcase
      SCRIPT_TYPES.include?(type) ? type : 'madani'
    end
  end

  def show_madani_script_comparision?
    script_type == 'madani'
  end

  def riwayah_comparison?
    script_type == 'riwayah'
  end

  # --- family modes (character audit) --------------------------------------

  def family_scripts
    @family_scripts ||= Script.in_family(script_type).to_a
  end

  # the table columns, including the glyph scripts, in their compare order
  def comparision_scripts
    family_scripts.select { |s| s.meta_data['compare_position'] }.sort_by { |s| s.meta_data['compare_position'] }.map(&:comparison_key)
  end

  # the unicode columns whose characters are audited
  def scripts
    @scripts ||= family_scripts.select { |s| s.meta_data['charset_position'] }.sort_by { |s| s.meta_data['charset_position'] }.map(&:column_name)
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

  def script_display_name(key)
    @display_names ||= Script.all.to_h { |s| [s.comparison_key, s.name] }
    @display_names[key] || key
  end

  def review_words
    return [] if char.blank? || words.blank?

    @review_words ||= words.select do |word|
      !scripts.all? { |script| word.send(script).to_s.include?(char) }
    end.map(&:location)
  end

  # --- riwayah mode (two scripts side by side) ------------------------------

  def comparable_scripts
    @comparable_scripts ||= Script.comparable.includes(:riwayah).order(:id).to_a
  end

  def script_a
    @script_a ||= find_script(params[:script_a]) || comparable_scripts.find { |s| s.slug == 'qpc-hafs' } || comparable_scripts.first
  end

  def script_b
    @script_b ||= find_script(params[:script_b]) || comparable_scripts.find { |s| s.slug == 'qpc-warsh' } || comparable_scripts.last
  end

  def chapter
    @chapter ||= Chapter.find_by(id: params[:filter_chapter].to_i) || Chapter.find_by(chapter_number: 1)
  end

  # the surah's Kufi verses, one page at a time; an ayah number narrows to one
  def ayahs
    @ayahs ||= begin
      list = Verse.where(chapter_id: chapter.id).order(:verse_index)
      list = list.where(verse_number: params[:verse_number].to_i) if params[:verse_number].to_i > 0
      paginate(list, items: AYAHS_PER_PAGE)
    end
  end

  def text_for(verse, script)
    verse.text_for(script)
  end

  # verse_id => the ayah keys of the script's riwayah numbering, when it is not the Kufi one
  def ayah_keys_for(script, verses)
    numbering = script.riwayah&.default_numbering
    return {} if numbering.nil? || numbering.kufi?

    AyahMapping.where(numbering_id: numbering.id, verse_id: verses.map(&:id)).includes(:ayah).to_h { |m| [m.verse_id, m.ayahs.map(&:ayah_key)] }
  end

  def same_riwayah?
    script_a.riwayah_id == script_b.riwayah_id
  end

  # the surah's words whose spelling (or presence) separates the two riwayat
  def differing_words
    @differing_words ||= begin
      a = script_a.riwayah&.slug
      b = script_b.riwayah&.slug
      if a.nil? || b.nil? || a == b
        []
      else
        WordDifference.in_chapter(chapter.id).includes(:word).order(:word_id).select { |d| d.form_for(a) != d.form_for(b) }
      end
    end
  end

  def meta_title
    if riwayah_comparison?
      "Quran Scripts Comparison - #{script_a&.name} vs #{script_b&.name}, surah #{chapter&.chapter_number}"
    elsif char.present?
      "Quran Scripts Comparison - Words containing '#{char}'"
    elsif params[:script_type].present?
      "Quran Scripts Comparison - #{script_type.capitalize} Script Character Selection"
    else
      "Quran Scripts Comparison"
    end
  end

  def meta_description
    "Compare different Quranic script variants (Madani and Indopak) to identify inconsistencies and missing characters, or two riwayat side by side with their differing words. Essential for script proofreading and quality assurance."
  end

  def meta_keywords
    'Quran script comparison, script variants, Madani script, Indopak script, riwayah comparison, Hafs Warsh differences, Quran font compatibility, script proofreading'
  end

  private

  def find_script(slug)
    slug.present? ? comparable_scripts.find { |s| s.slug == slug } : nil
  end
end
