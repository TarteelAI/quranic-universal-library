# Reads and writes the grammar features packed in a segment's pos_tags,
# e.g. "3MP,IMPF,MOOD:IND" is third person, masculine, plural, imperfect, indicative.
# Tags that aren't a feature (ADJ, PN, CONJ...) are kept as other tags.
class Morphology::SegmentTags
  FEATURES = {
    segment_type: { label: 'Segment type', blank: 'Stem', options: { 'PREF' => 'Prefix', 'SUFF' => 'Suffix' } },
    case: { label: 'Case', options: { 'NOM' => 'Nominative · مرفوع', 'ACC' => 'Accusative · منصوب', 'GEN' => 'Genitive · مجرور' } },
    state: { label: 'Definiteness', options: { 'INDEF' => 'Indefinite · نكرة' } },
    aspect: { label: 'Aspect', options: { 'PERF' => 'Perfect · الماضي', 'IMPF' => 'Imperfect · المضارع', 'IMPV' => 'Imperative · الأمر' } },
    mood: { label: 'Mood', options: { 'MOOD:IND' => 'Indicative · مرفوع', 'MOOD:SUBJ' => 'Subjunctive · منصوب', 'MOOD:JUS' => 'Jussive · مجزوم' } },
    voice: { label: 'Voice', blank: 'Active', options: { 'PASS' => 'Passive · مبني للمجهول' } },
    derivation: { label: 'Derivation', options: { 'ACT_PCPL' => 'Active participle · اسم فاعل', 'PASS_PCPL' => 'Passive participle · اسم مفعول', 'VN' => 'Verbal noun · مصدر' } },
    family: { label: 'Special family', options: { 'FAM:كَان' => 'كان وأخواتها', 'FAM:إِنّ' => 'إنّ وأخواتها', 'FAM:كَاد' => 'كاد وأخواتها' } }
  }.freeze

  # Person, gender and number share one tag: 3MP, MS, F, 2D...
  PGN = {
    person: { label: 'Person', options: { '1' => 'First · المتكلم', '2' => 'Second · المخاطب', '3' => 'Third · الغائب' } },
    gender: { label: 'Gender', options: { 'M' => 'Masculine · مذكر', 'F' => 'Feminine · مؤنث' } },
    number: { label: 'Number', options: { 'S' => 'Singular · مفرد', 'D' => 'Dual · مثنى', 'P' => 'Plural · جمع' } }
  }.freeze
  PGN_TAG = /\A(?<person>[123])?(?<gender>[MF])?(?<number>[SDP])?\z/

  attr_reader :tags, :pos_key

  def initialize(pos_tags, pos_key)
    @tags = pos_tags.to_s.split(',').map(&:strip).compact_blank
    @pos_key = pos_key
  end

  def features
    values = FEATURES.to_h { |name, feature| [name, tags.find { |tag| feature[:options].key?(tag) }] }
    match = pgn_tag && pgn_tag.match(PGN_TAG)
    PGN.each_key { |name| values[name] = match && match[name] }
    values
  end

  # Tags that aren't a feature or the verb form
  def other_tags
    tags.reject { |tag| feature_tag?(tag) || tag.start_with?('VF:') }
  end

  # New pos_tags with the given features, other tags and verb form,
  # keeping the tags that didn't change where they were.
  def build(values, others, verb_form)
    others = others.map { |tag| tag.to_s.delete_prefix('new:').strip.upcase }.compact_blank
    result = tags.dup

    FEATURES.each do |name, feature|
      replace(result, ->(tag) { feature[:options].key?(tag) }, values[name].presence_in(feature[:options].keys))
    end

    pgn = PGN.keys.map { |name| values[name].presence_in(PGN[name][:options].keys) }.join.presence
    replace(result, ->(tag) { pgn_tag?(tag) }, pgn)
    replace(result, ->(tag) { tag.start_with?('VF:') }, verb_form.presence && "VF:#{verb_form}")

    result.reject! { |tag| !feature_tag?(tag) && !tag.start_with?('VF:') && !others.include?(tag) }
    (result | others).uniq.join(',').presence
  end

  private

  def replace(list, matcher, value)
    index = list.index(&matcher)
    list.reject!(&matcher)
    return unless value

    list.insert(index || list.size, value)
  end

  def pgn_tag
    tags.find { |tag| pgn_tag?(tag) }
  end

  # "P" alone is the part of speech of a particle, not plural
  def pgn_tag?(tag)
    tag.present? && tag != pos_key && tag.match?(PGN_TAG)
  end

  def feature_tag?(tag)
    pgn_tag?(tag) || FEATURES.values.any? { |feature| feature[:options].key?(tag) }
  end
end
