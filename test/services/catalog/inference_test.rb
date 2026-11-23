require_relative '../../test_helper'
require_relative '../../../app/services/catalog/inference'

# Table-driven: each row gives the facts of a resource and the value the rule must infer, or nil
# when the facts do not show one.
class CatalogInferenceTest < Minitest::Test
  Inference = Catalog::Inference

  def facts(**fields)
    Inference::Facts.new(id: 1, type: 'quran-script', name: 'Sample', cardinality: '1_word', published: true,
                         status: 'stable', text_types: [], font_codes: [], tags: [], formats: [], requires: [],
                         **fields)
  end

  def mushaf(**fields)
    Inference::Mushaf.new(font: 'qpc-hafs', default: false, pages: 604, lines: 15, **fields)
  end

  def assert_rows(rows)
    rows.each do |expected, given|
      actual = yield(given)
      message = "#{given.inspect} gave #{actual.inspect}, expected #{expected.inspect}"
      expected.nil? ? assert_nil(actual, message) : assert_equal(expected, actual, message)
    end
  end

  SCRIPT_FAMILIES = [
    ['madani', { type: 'quran-script', text_types: ['text_uthmani'], font_codes: ['me_quran'] }],
    ['madani', { type: 'quran-script', text_types: ['code_v1'], font_codes: ['v1'] }],
    ['madani', { type: 'quran-script', text_types: ['text_digital_khatt'], font_codes: ['digitalkhatt'] }],
    ['indopak', { type: 'quran-script', text_types: ['text_indopak_nastaleeq'] }],
    ['indopak', { type: 'quran-script', text_types: ['text_qpc_nastaleeq_hafs'] }],
    ['indopak', { type: 'quran-script', text_types: ['text_digital_khatt_indopak'],
                  font_codes: ['indopak-nastaleeq'] }],
    # The script's own text type wins over the font that draws it.
    ['other', { type: 'quran-script', text_types: ['text_imlaei'], font_codes: ['me-quran or qpc-hafs'] }],
    ['other', { type: 'font', text_types: ['text_arabic_sign'], font_codes: ['sign-language'] }],
    # Riwayah scripts and image scripts name no family.
    [nil, { type: 'quran-script', text_types: ['qpc-warsh'], font_codes: ['qpc-warsh'] }],
    [nil, { type: 'quran-script', text_types: ['qa_black_image_url'] }],
    ['madani', { type: 'font', text_types: ['code_v2'], font_codes: ['p1-v4'] }],
    ['indopak', { type: 'font', font_codes: ['indopak-nastaleeq'], tags: ['Indopak'] }],
    # Decoration fonts name no Quran script.
    [nil, { type: 'font', font_codes: ['v4-surah-name', 'surah-names/v2'] }],
    ['indopak', { type: 'mushaf-layout', font_codes: ['mushaf-indopak-nastaleeq-hanafi-compressed'] }],
    ['madani', { type: 'mushaf-layout', font_codes: ['qpc-hafs'] }],
    [nil, { type: 'mushaf-layout', font_codes: ['svg'] }],
    # Tags decide only when nothing else does, and never contradict.
    ['madani', { type: 'mushaf-layout', tags: ['Madani', 'Mushaf layout'] }],
    [nil, { type: 'mushaf-layout', font_codes: ['qpc-hafs'], tags: ['Indopak'] }],
    [nil, { type: 'mushaf-layout', font_codes: %w[qpc-hafs indopak] }],
    [nil, { type: 'translation', text_types: ['text_uthmani'] }]
  ].freeze

  def test_script_family
    assert_rows(SCRIPT_FAMILIES) { |given| Inference.script_family(facts(**given)) }
  end

  RENDERINGS = [
    ['glyph_page', { type: 'quran-script', text_types: ['code_v4'] }],
    ['image', { type: 'quran-script', text_types: ['rq_tajweed_image_url'] }],
    ['unicode_font', { type: 'quran-script', text_types: ['text_qpc_hafs'] }],
    ['unicode_font', { type: 'quran-script', text_types: ['qpc-warsh'] }],
    [nil, { type: 'quran-script' }],
    ['glyph_page', { type: 'mushaf-layout', font_codes: ['v4-tajweed'] }],
    ['glyph_page', { type: 'mushaf-layout', font_codes: ['v1'] }],
    ['image', { type: 'mushaf-layout', font_codes: ['img'] }],
    ['svg', { type: 'mushaf-layout', font_codes: ['svg'] }],
    ['unicode_font', { type: 'mushaf-layout', font_codes: ['digitalkhatt'] }],
    [nil, { type: 'mushaf-layout' }],
    ['glyph_page', { type: 'font', per_page: true, text_types: ['code_v2'] }],
    ['svg', { type: 'font', svg: true }],
    ['unicode_font', { type: 'font', text_types: ['text_qpc_hafs'] }],
    [nil, { type: 'font', font_codes: ['surah-header'] }],
    [nil, { type: 'tafsir', text_types: ['text_qpc_hafs'] }]
  ].freeze

  def test_rendering
    assert_rows(RENDERINGS) { |given| Inference.rendering(facts(**given)) }
  end

  def catalog_for_status
    [
      facts(id: 50, type: 'quran-script', name: 'Tajweed Images(Old)'),
      facts(id: 51, type: 'quran-script', name: 'Tajweed Images(New)', published: false),
      facts(id: 476, type: 'transliteration', name: 'Syllables Transliteration(Old)', cardinality: '1_ayah'),
      facts(id: 477, type: 'transliteration', name: 'Syllables Transliteration', cardinality: '1_ayah'),
      facts(id: 475, type: 'transliteration', name: 'Syllables Transliteration 2', cardinality: '1_ayah'),
      facts(id: 60, type: 'font', name: 'Sample Font (old)'),
      facts(id: 61, type: 'font', name: 'Sample Font (new)'),
      facts(id: 62, type: 'font', name: 'Sample Font'),
      facts(id: 70, type: 'quran-script', name: 'Pair (Old)', cardinality: '1_ayah'),
      facts(id: 71, type: 'quran-script', name: 'Pair', cardinality: '1_word'),
      facts(id: 402, type: 'recitation', name: 'Reciter [older recitation]', cardinality: '1_chapter'),
      facts(id: 403, type: 'recitation', name: 'Reciter', cardinality: '1_chapter'),
      facts(id: 80, type: 'font', name: 'QPC V1 Font'),
      facts(id: 81, type: 'font', name: 'QPC V2 Font')
    ]
  end

  STATUSES = [
    # An "(Old)" name with no published replacement is legacy.
    [['legacy', nil], 50],
    [nil, 51],
    # The replacement has the same name without the marker, in the same type and granularity.
    [['superseded', 477], 476],
    [nil, 477],
    [nil, 475],
    # Two replacements are ambiguous: legacy only.
    [['legacy', nil], 60],
    # A different granularity is not a replacement.
    [['legacy', nil], 70],
    # "older recitation" names the recording, not the resource.
    [nil, 402],
    # Version numbers in names are separate prints, not replacements.
    [nil, 80],
    [nil, 81]
  ].freeze

  def test_status
    catalog = catalog_for_status
    assert_rows(STATUSES) { |id| Inference.status(catalog.find { |row| row.id == id }, catalog) }
  end

  def layout(id, **fields)
    facts(id: id, type: 'mushaf-layout', cardinality: '1_page', script_family: 'madani', mushaf: mushaf, **fields)
  end

  def font(id, **fields)
    facts(id: id, type: 'font', cardinality: 'quran', script_family: 'madani', **fields)
  end

  def test_recommended_layout_is_the_one_on_a_default_mushaf_and_its_required_font
    catalog = [
      layout(1, mushaf: mushaf(default: true), requires: [10]),
      layout(2, requires: [11]),
      layout(3, script_family: 'indopak', mushaf: mushaf(font: 'indopak-nastaleeq')),
      font(10), font(11)
    ]

    assert_equal [1, 10], Inference.recommended(catalog).sort
  end

  RECOMMENDED = [
    # No default mushaf: the data cannot say which layout to recommend.
    [[], [[:layout, 1, {}], [:layout, 2, {}]]],
    # Two default mushafs in one family are ambiguous.
    [[], [[:layout, 1, { mushaf: { default: true } }], [:layout, 2, { mushaf: { default: true } }]]],
    # One per family.
    [[1, 2], [[:layout, 1, { mushaf: { default: true } }],
              [:layout, 2, { script_family: 'indopak', mushaf: { default: true } }]]],
    # Never an unpublished, legacy or superseded layout, or one with no script family.
    [[], [[:layout, 1, { mushaf: { default: true }, published: false }]]],
    [[], [[:layout, 1, { mushaf: { default: true }, status: 'legacy' }]]],
    [[], [[:layout, 1, { mushaf: { default: true }, status: 'superseded' }]]],
    [[], [[:layout, 1, { mushaf: { default: true }, script_family: nil }]]],
    # A family where a person already recommended another layout gets no drafted one.
    [[], [[:layout, 1, { mushaf: { default: true } }], [:layout, 2, { recommended_by_person: true }]]],
    # A person accepting one half of the pair keeps the other half drafted.
    [[1, 10], [[:layout, 1, { mushaf: { default: true }, requires: [10], recommended_by_person: true }],
               [:font, 10, {}]]],
    [[1, 10], [[:layout, 1, { mushaf: { default: true }, requires: [10] }],
               [:font, 10, { recommended_by_person: true }]]],
    # A person rejecting the layout takes the font's evidence away too.
    [[], [[:layout, 1, { mushaf: { default: true }, requires: [10], recommended_by_person: false }],
          [:font, 10, {}]]],
    # The font must be of the layout's script family.
    [[1], [[:layout, 1, { mushaf: { default: true }, requires: [10] }], [:font, 10, { script_family: 'indopak' }]]],
    # The required font must be published, not legacy, and the only font the layout requires.
    [[1], [[:layout, 1, { mushaf: { default: true }, requires: [10] }], [:font, 10, { status: 'legacy' }]]],
    [[1], [[:layout, 1, { mushaf: { default: true }, requires: [10] }], [:font, 10, { published: false }]]],
    [[1], [[:layout, 1, { mushaf: { default: true }, requires: [10, 11] }], [:font, 10, {}], [:font, 11, {}]]],
    # Other types are never recommended by inference.
    [[], [[:font, 10, { mushaf: { default: true } }]]]
  ].freeze

  def test_recommended
    assert_rows(RECOMMENDED) do |rows|
      catalog = rows.map do |kind, id, fields|
        fields = fields.merge(mushaf: mushaf(**fields[:mushaf])) if fields[:mushaf].is_a?(Hash)
        send(kind, id, **fields)
      end
      Inference.recommended(catalog).sort
    end
  end

  def font_catalog
    [
      font(238, font_codes: ['p1-v1', 'v1']),
      font(249, font_codes: ['p1-v2', 'v2']),
      font(240, font_codes: ['p1-v4', 'v4-tajweed']),
      font(242, font_codes: ['indopak-nastaleeq', 'indopak-4-2-2-waqf-lazim']),
      font(243, font_codes: ['me-quran']),
      font(245, font_codes: ['qpc-hafs']),
      font(248, font_codes: ['digitalkhaat', 'digitalkhatt']),
      font(247, font_codes: ['digitalkhaat-v2', 'digitalkhatt-v2']),
      font(591, font_codes: ['header-surah-name']),
      font(592, font_codes: ['header-surah-name']),
      font(244, font_codes: ['pdms-saleem'], published: false)
    ]
  end

  REQUIRED_FONTS = [
    [249, { type: 'mushaf-layout', font_codes: ['v2'], rendering: 'glyph_page' }],
    [240, { type: 'mushaf-layout', font_codes: ['v4-tajweed'], rendering: 'glyph_page' }],
    [243, { type: 'mushaf-layout', font_codes: ['me_quran'], rendering: 'unicode_font' }],
    [242, { type: 'mushaf-layout', font_codes: ['indopak-nastaleeq'], rendering: 'unicode_font' }],
    [248, { type: 'mushaf-layout', font_codes: ['digitalkhatt'], rendering: 'unicode_font' }],
    # No published font has the code, or more than one has it.
    [nil, { type: 'mushaf-layout', font_codes: ['mushaf-indopak-nastaleeq-hanafi-compressed'] }],
    [nil, { type: 'mushaf-layout', font_codes: ['pdms-saleem'] }],
    [nil, { type: 'mushaf-layout', font_codes: ['header-surah-name'] }],
    [nil, { type: 'mushaf-layout', font_codes: ['svg'], rendering: 'svg' }],
    # A layout that already links to another font keeps the link a person made.
    [nil, { type: 'mushaf-layout', font_codes: ['qpc-hafs'], linked_fonts: [242] }],
    [245, { type: 'mushaf-layout', font_codes: ['qpc-hafs'], linked_fonts: [245] }],
    # Glyph scripts require their page font; Unicode scripts require nothing.
    [238, { type: 'quran-script', font_codes: ['v1'], rendering: 'glyph_page' }],
    [240, { type: 'quran-script', font_codes: ['v4-tajweed'], rendering: 'glyph_page' }],
    [nil, { type: 'quran-script', font_codes: ['qpc-hafs'], rendering: 'unicode_font' }],
    [nil, { type: 'font', font_codes: ['qpc-hafs'] }]
  ].freeze

  def test_required_font
    fonts = font_catalog
    assert_rows(REQUIRED_FONTS) { |given| Inference.required_font(facts(linked_fonts: [], **given), fonts) }
  end

  SUMMARIES = [
    ['English translation, ayah by ayah. JSON and SQLite files.',
     { type: 'translation', language: 'English', cardinality: '1_ayah', formats: %w[simple.json simple.sqlite json] }],
    ['Urdu tafsir, for one ayah or a group of ayahs. JSON and SQLite files.',
     { type: 'tafsir', language: 'Urdu', cardinality: 'n_ayah', formats: %w[sqlite json] }],
    ['Translation, word by word.', { type: 'translation', cardinality: '1_word' }],
    ['Bengali introduction to each surah. JSON, SQLite and CSV files.',
     { type: 'surah-info', language: 'Bengali', cardinality: '1_chapter', formats: %w[csv json sqlite] }],
    ['Quran recitation, surah by surah. JSON and SQLite files.',
     { type: 'recitation', cardinality: '1_chapter', formats: %w[json sqlite] }],
    ['Quran text in Unicode, word by word. JSON and SQLite files.',
     { type: 'quran-script', rendering: 'unicode_font', cardinality: '1_word', formats: %w[json sqlite] }],
    ['Quran text as glyph codes for page fonts, ayah by ayah.',
     { type: 'quran-script', rendering: 'glyph_page', cardinality: '1_ayah' }],
    ['Quran text as word images, word by word.', { type: 'quran-script', rendering: 'image', cardinality: '1_word' }],
    ['Quran text, word by word.', { type: 'quran-script', cardinality: '1_word' }],
    ['Glyph font with one file for each mushaf page. TTF, WOFF and WOFF2 files.',
     { type: 'font', rendering: 'glyph_page', cardinality: '1_page', formats: %w[woff2 ttf woff] }],
    ['Font for Quran text. TTF and WOFF2 files.',
     { type: 'font', rendering: 'unicode_font', cardinality: 'quran', formats: %w[ttf woff2 Ligatures] }],
    ['Font. SVG files.', { type: 'font', cardinality: '1_chapter', formats: %w[svg] }],
    ['Mushaf layout with 604 pages and 15 lines on each page. SQLite and DOCX files.',
     { type: 'mushaf-layout', cardinality: '1_page', mushaf: Inference::Mushaf.new(pages: 604, lines: 15),
       formats: %w[docx sqlite] }],
    ['Mushaf layout, page by page.', { type: 'mushaf-layout', cardinality: '1_page' }],
    ['Morphology, word by word. SQLite files.',
     { type: 'morphology', type_label: 'Morphology', cardinality: '1_word', formats: %w[sqlite] }],
    ['Quran metadata, juz by juz. JSON and SQLite files.',
     { type: 'quran-metadata', type_label: 'Quran metadata', cardinality: '1_juz', formats: %w[json sqlite] }],
    ['Mutashabihat, phrase by phrase. JSON files.',
     { type: 'mutashabihat', type_label: 'Mutashabihat', cardinality: '1_phrase', formats: %w[json] }],
    ['English transliteration, ayah by ayah.', { type: 'transliteration', language: 'English', cardinality: '1_ayah' }]
  ].freeze

  def test_summary
    assert_rows(SUMMARIES) { |given| Inference.summary(facts(**given)) }
  end

  def test_summary_drops_the_formats_to_fit_on_one_line
    long = facts(type: 'translation', language: 'A' * 120, cardinality: '1_ayah', formats: %w[json sqlite])

    assert_equal "#{'A' * 120} translation, ayah by ayah.", Inference.summary(long)
    assert_nil Inference.summary(facts(type: 'translation', language: 'A' * 200, cardinality: '1_ayah'))
  end
end
