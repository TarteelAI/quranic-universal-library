require_relative '../../../test_helper'
require_relative '../../../../app/services/morphology/treebank/level_builder'

module Morphology
  module WordSegment
    POS_TAG_COLORS = {
      n: 'sky', pn: 'blue', pron: 'sky', dem: 'brown', rel: 'gold',
      adj: 'purple', v: 'seagreen', p: 'rust', intg: 'rose', voc: 'green',
      neg: 'red', emph: 'navy', prp: 'gold', impv: 'orange', fut: 'orange',
      conj: 'navy', det: 'gray', inl: 'orange', t: 'orange', loc: 'orange',
      acc: 'orange', cond: 'orange', sub: 'gold', res: 'navy', exp: 'orange',
      avr: 'orange', cert: 'orange', ret: 'orange', prev: 'orange', ans: 'navy',
      inc: 'orange', sur: 'orange', sup: 'navy', exh: 'orange', impn: 'orange',
      exl: 'orange', eq: 'navy', rem: 'navy', caus: 'orange', amd: 'navy',
      pro: 'red', circ: 'navy', rslt: 'navy', int: 'orange', com: 'navy'
    }.freeze
  end
end

require_relative '../../../../app/services/morphology/treebank/colors'
require_relative '../../../../app/presenters/morphology/treebank_presenter'

class PresenterPayloadTest < Minitest::Test
  EN = {
    'morphology.edge_relations.subj'  => 'Subject',
    'morphology.edge_relations.obj'   => 'Object',
    'morphology.edge_relations.conj'  => 'Conjunction',
    'morphology.edge_relations.root'  => 'Sentence root',
    'morphology.edge_relations.nonrel' => 'No relation',
    'morphology.edge_relations.VS'    => 'Verbal Sentence',
    'morphology.pos_tags.PRON'        => 'Pronoun',
    'morphology.pos_tags.V'           => 'Verb',
    'morphology.pos_tags.N'           => 'Noun',
    'morphology.pos_tags.P'           => 'Preposition',
  }.freeze

  AR = {
    'morphology.edge_relations.subj'  => 'فاعل',
    'morphology.edge_relations.obj'   => 'مفعول به',
    'morphology.edge_relations.conj'  => 'معطوف',
    'morphology.edge_relations.root'  => 'رأس الجملة',
    'morphology.edge_relations.nonrel' => 'بدون علاقة',
    'morphology.edge_relations.VS'    => 'جملة فعلية',
    'morphology.pos_tags.PRON'        => 'ضمير',
    'morphology.pos_tags.V'           => 'فعل',
    'morphology.pos_tags.N'           => 'اسم',
    'morphology.pos_tags.P'           => 'حرف جر',
  }.freeze

  def make_translator(dict)
    lambda do |key, locale:, default:|
      dict[key] || default
    end
  end

  Token = Struct.new(
    :id, :position_in_sentence, :location, :text_qpc_hafs, :text_uthmani,
    :pos_key, :token_type, :chapter_number, :verse_number, :word_number,
    :head_token_id, :rel_label, :rel_governor, :ref_token_position,
    :dependent_is_phrase, :head_is_phrase,
    :is_constituent, :constituent_span_start, :constituent_span_end,
    :constituent_label, :constituent_text,
    keyword_init: true
  )

  FakeSentence = Struct.new(:sentence_number, :text_qpc_hafs, :first_verse, :last_verse, :word_tokens, keyword_init: true) do
    def verse_range
      fv = first_verse
      lv = last_verse
      fv_key = "#{fv[:chapter_id]}:#{fv[:verse_number]}"
      lv_key = "#{lv[:chapter_id]}:#{lv[:verse_number]}"
      fv_key == lv_key ? fv_key : "#{fv_key} - #{lv_key}"
    end
  end

  FakeVerse = Struct.new(:chapter_id, :verse_number, :verse_key, keyword_init: true)
  FakeChapter = Struct.new(:name_arabic, :name_simple, keyword_init: true)

  def verse_1_5_tokens
    [
      Token.new(id: 1,  position_in_sentence: 0, location: '1:5:1:1', text_qpc_hafs: 'إِيَّاكَ',   text_uthmani: 'إِيَّاكَ',
                pos_key: 'PRON', token_type: 'surface', chapter_number: 1, verse_number: 5, word_number: 1,
                head_token_id: 2,  rel_label: 'obj',  rel_governor: nil, ref_token_position: 1,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 2,  position_in_sentence: 1, location: '1:5:2:1', text_qpc_hafs: 'نَعْبُدُ',    text_uthmani: 'نَعْبُدُ',
                pos_key: 'V',    token_type: 'surface', chapter_number: 1, verse_number: 5, word_number: 2,
                head_token_id: nil, rel_label: 'root', rel_governor: nil, ref_token_position: 1,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: -1, constituent_span_start: 0, constituent_span_end: 2,
                constituent_label: 'VS', constituent_text: 'إِيَّاكَ نَعْبُدُ (نَحْنُ)'),
      Token.new(id: 3,  position_in_sentence: 2, location: nil,        text_qpc_hafs: '(نَحْنُ)',  text_uthmani: nil,
                pos_key: 'PRON', token_type: 'implicit_pronoun', chapter_number: 1, verse_number: 5, word_number: nil,
                head_token_id: 2,  rel_label: 'subj', rel_governor: nil, ref_token_position: 1,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 4,  position_in_sentence: 3, location: '1:5:3:1', text_qpc_hafs: 'وَإِيَّاكَ',  text_uthmani: 'وَإِيَّاكَ',
                pos_key: 'PRON', token_type: 'surface', chapter_number: 1, verse_number: 5, word_number: 3,
                head_token_id: nil, rel_label: 'nonrel', rel_governor: nil, ref_token_position: 3,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 5,  position_in_sentence: 4, location: '1:5:4:1', text_qpc_hafs: 'إِيَّاكَ',   text_uthmani: 'إِيَّاكَ',
                pos_key: 'PRON', token_type: 'surface', chapter_number: 1, verse_number: 5, word_number: 4,
                head_token_id: 6,  rel_label: 'obj',  rel_governor: nil, ref_token_position: 4,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 6,  position_in_sentence: 5, location: '1:5:5:1', text_qpc_hafs: 'نَسْتَعِينُ', text_uthmani: 'نَسْتَعِينُ',
                pos_key: 'V',    token_type: 'surface', chapter_number: 1, verse_number: 5, word_number: 5,
                head_token_id: 2,  rel_label: 'conj', rel_governor: nil, ref_token_position: 5,
                dependent_is_phrase: true, head_is_phrase: true,
                is_constituent: 1, constituent_span_start: 4, constituent_span_end: 6,
                constituent_label: 'VS', constituent_text: 'إِيَّاكَ نَسْتَعِينُ (نَحْنُ)'),
      Token.new(id: 7,  position_in_sentence: 6, location: nil,        text_qpc_hafs: '(نَحْنُ)',  text_uthmani: nil,
                pos_key: 'PRON', token_type: 'implicit_pronoun', chapter_number: 1, verse_number: 5, word_number: nil,
                head_token_id: 6,  rel_label: 'subj', rel_governor: nil, ref_token_position: 5,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil)
    ]
  end

  def verse_1_2_4_tokens
    [
      Token.new(id: 1, position_in_sentence: 0, location: '1:2:1:1', text_qpc_hafs: 'ٱلْحَمْدُ', text_uthmani: 'ٱلْحَمْدُ',
                pos_key: 'N', token_type: 'surface', chapter_number: 1, verse_number: 2, word_number: 1,
                head_token_id: nil, rel_label: 'root', rel_governor: nil, ref_token_position: 0,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 2, position_in_sentence: 1, location: '1:2:2:1', text_qpc_hafs: 'لِلَّهِ', text_uthmani: 'لِلَّهِ',
                pos_key: 'N', token_type: 'surface', chapter_number: 1, verse_number: 2, word_number: 2,
                head_token_id: 1, rel_label: 'nonrel', rel_governor: nil, ref_token_position: 1,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 3, position_in_sentence: 2, location: '1:2:3:1', text_qpc_hafs: 'رَبِّ', text_uthmani: 'رَبِّ',
                pos_key: 'N', token_type: 'surface', chapter_number: 1, verse_number: 2, word_number: 3,
                head_token_id: 2, rel_label: 'nonrel', rel_governor: nil, ref_token_position: 2,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 4, position_in_sentence: 3, location: '1:2:4:1', text_qpc_hafs: 'ٱلْعَٰلَمِينَ', text_uthmani: 'ٱلْعَٰلَمِينَ',
                pos_key: 'N', token_type: 'surface', chapter_number: 1, verse_number: 2, word_number: 4,
                head_token_id: 3, rel_label: 'nonrel', rel_governor: nil, ref_token_position: 3,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 5, position_in_sentence: 4, location: '1:3:1:1', text_qpc_hafs: 'ٱلرَّحْمَٰنِ', text_uthmani: 'ٱلرَّحْمَٰنِ',
                pos_key: 'N', token_type: 'surface', chapter_number: 1, verse_number: 3, word_number: 1,
                head_token_id: 1, rel_label: 'nonrel', rel_governor: nil, ref_token_position: 4,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 6, position_in_sentence: 5, location: '1:3:2:1', text_qpc_hafs: 'ٱلرَّحِيمِ', text_uthmani: 'ٱلرَّحِيمِ',
                pos_key: 'N', token_type: 'surface', chapter_number: 1, verse_number: 3, word_number: 2,
                head_token_id: 5, rel_label: 'nonrel', rel_governor: nil, ref_token_position: 5,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 7, position_in_sentence: 6, location: '1:4:1:1', text_qpc_hafs: 'مَٰلِكِ', text_uthmani: 'مَٰلِكِ',
                pos_key: 'N', token_type: 'surface', chapter_number: 1, verse_number: 4, word_number: 1,
                head_token_id: 1, rel_label: 'nonrel', rel_governor: nil, ref_token_position: 6,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 8, position_in_sentence: 7, location: '1:4:2:1', text_qpc_hafs: 'يَوْمِ', text_uthmani: 'يَوْمِ',
                pos_key: 'N', token_type: 'surface', chapter_number: 1, verse_number: 4, word_number: 2,
                head_token_id: 7, rel_label: 'nonrel', rel_governor: nil, ref_token_position: 7,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil),
      Token.new(id: 9, position_in_sentence: 8, location: '1:4:3:1', text_qpc_hafs: 'ٱلدِّينِ', text_uthmani: 'ٱلدِّينِ',
                pos_key: 'N', token_type: 'surface', chapter_number: 1, verse_number: 4, word_number: 3,
                head_token_id: 8, rel_label: 'nonrel', rel_governor: nil, ref_token_position: 8,
                dependent_is_phrase: false, head_is_phrase: false,
                is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
                constituent_label: nil, constituent_text: nil)
    ]
  end

  def make_multi_verse_sentence(tokens)
    FakeSentence.new(
      sentence_number: 1,
      text_qpc_hafs: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
      first_verse: { chapter_id: 1, verse_number: 2 },
      last_verse:  { chapter_id: 1, verse_number: 4 },
      word_tokens: tokens
    )
  end

  def make_multi_verse_presenter(locale:)
    sentence = make_multi_verse_sentence(verse_1_2_4_tokens)
    verse   = FakeVerse.new(chapter_id: 1, verse_number: 2, verse_key: '1:2')
    chapter = FakeChapter.new(name_arabic: 'الفاتحة', name_simple: 'Al-Fatihah')
    dict    = locale == 'ar' ? AR : EN
    Morphology::TreebankPresenter.new(
      verse: verse,
      sentences: [sentence],
      locale: locale,
      translator: make_translator(dict),
      chapter: chapter
    )
  end

  def test_banner_multi_verse_preserves_reading_order_and_spacing
    payload = make_multi_verse_presenter(locale: 'ar').to_json_payload
    text = payload[:sentences][0][:banner][:text]
    inner = text[1..-2]
    expected = 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ مَٰلِكِ يَوْمِ ٱلدِّينِ'
    assert_equal expected, inner,
      "banner across verses 2-4 must join words in reading order with single spaces, not merge same word_number across verses"
  end

  def make_sentence(tokens)
    verse_hash = { chapter_id: 1, verse_number: 5 }
    FakeSentence.new(
      sentence_number: 4,
      text_qpc_hafs: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ',
      first_verse: verse_hash,
      last_verse:  verse_hash,
      word_tokens: tokens
    )
  end

  def make_presenter(locale:, tokens: nil)
    toks = tokens || verse_1_5_tokens
    sentence = make_sentence(toks)
    verse   = FakeVerse.new(chapter_id: 1, verse_number: 5, verse_key: '1:5')
    chapter = FakeChapter.new(name_arabic: 'الفاتحة', name_simple: 'Al-Fatihah')
    dict    = locale == 'ar' ? AR : EN
    Morphology::TreebankPresenter.new(
      verse: verse,
      sentences: [sentence],
      locale: locale,
      translator: make_translator(dict),
      chapter: chapter
    )
  end

  def test_self_referencing_token_produces_no_edge
    base_tokens = verse_1_5_tokens
    self_ref_token = Token.new(
      id: 99, position_in_sentence: 1, location: '1:5:2:1', text_qpc_hafs: 'نَعْبُدُ', text_uthmani: 'نَعْبُدُ',
      pos_key: 'V', token_type: 'surface', chapter_number: 1, verse_number: 5, word_number: 2,
      head_token_id: 99, rel_label: 'root', rel_governor: nil, ref_token_position: 1,
      dependent_is_phrase: false, head_is_phrase: false,
      is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
      constituent_label: nil, constituent_text: nil
    )
    verse = FakeVerse.new(chapter_id: 1, verse_number: 5, verse_key: '1:5')
    chapter = FakeChapter.new(name_arabic: 'الفاتحة', name_simple: 'Al-Fatihah')
    sentence = FakeSentence.new(
      sentence_number: 1,
      text_qpc_hafs: 'نَعْبُدُ',
      first_verse: { chapter_id: 1, verse_number: 5 },
      last_verse:  { chapter_id: 1, verse_number: 5 },
      word_tokens: [self_ref_token]
    )
    presenter = Morphology::TreebankPresenter.new(
      verse: verse, sentences: [sentence], locale: 'en',
      translator: make_translator(EN), chapter: chapter
    )
    payload = presenter.to_json_payload
    edges = payload[:sentences][0][:edges]
    assert_empty edges, "self-referencing token (head == self) should produce no edge, got #{edges.inspect}"
  end

  def test_word_url_nil_for_implicit_pronoun
    payload = make_presenter(locale: 'en').to_json_payload
    tokens = payload[:sentences][0][:tokens]

    implicit_tokens = tokens.select { |t| t[:tokenType] == 'implicit_pronoun' }
    assert implicit_tokens.any?, "expected implicit_pronoun tokens"
    implicit_tokens.each do |t|
      assert_nil t[:wordUrl], "implicit_pronoun should have nil wordUrl, got #{t[:wordUrl]}"
    end
  end

  def test_word_url_present_for_surface_tokens
    payload = make_presenter(locale: 'en').to_json_payload
    tokens = payload[:sentences][0][:tokens]

    surface_tokens = tokens.select { |t| t[:tokenType] == 'surface' }
    assert surface_tokens.any?, "expected surface tokens"
    surface_tokens.each do |t|
      assert_match %r{/morphology/word\?location=}, t[:wordUrl].to_s,
        "surface token should have wordUrl, got #{t[:wordUrl].inspect}"
    end
  end

  def test_direction_left_when_from_greater_than_to
    payload = make_presenter(locale: 'en').to_json_payload
    edges = payload[:sentences][0][:edges]

    left_edges = edges.select { |e| e[:from] > e[:to] }
    assert left_edges.any?, "expected at least one left-direction edge"
    left_edges.each do |e|
      assert_equal 'left', e[:direction], "from=#{e[:from]} to=#{e[:to]} should be 'left'"
    end
  end

  def test_direction_right_when_from_less_than_to
    payload = make_presenter(locale: 'en').to_json_payload
    edges = payload[:sentences][0][:edges]

    right_edges = edges.select { |e| e[:from] < e[:to] }
    assert right_edges.any?, "expected at least one right-direction edge"
    right_edges.each do |e|
      assert_equal 'right', e[:direction], "from=#{e[:from]} to=#{e[:to]} should be 'right'"
    end
  end

  def test_phrase_nodes_passthrough
    payload = make_presenter(locale: 'en').to_json_payload
    phrase_nodes = payload[:sentences][0][:phraseNodes]

    assert_equal 2, phrase_nodes.size, "expected 2 phrase nodes for 1:5"
    phrase_nodes.each do |n|
      assert_equal 1, n[:level]
      assert_equal 'VS', n[:labelKey]
      assert_includes [0, 4], n[:span][0]
    end
  end

  def test_phrase_nodes_include_head_position
    payload = make_presenter(locale: 'en').to_json_payload
    phrase_nodes = payload[:sentences][0][:phraseNodes]

    phrase_nodes.each do |n|
      assert n.key?(:headPosition), "phraseNode must include headPosition key"
    end

    head_positions = phrase_nodes.map { |n| n[:headPosition] }
    assert_includes head_positions, 1, "VS spanning 0-2 has head at position 1 (نَعْبُدُ)"
    assert_includes head_positions, 5, "VS spanning 4-6 has head at position 5 (نَسْتَعِينُ)"
  end

  def test_label_composition_with_governor
    tokens = verse_1_5_tokens.dup
    tokens[2] = Token.new(
      id: 3, position_in_sentence: 2, location: nil, text_qpc_hafs: '(نَحْنُ)', text_uthmani: nil,
      pos_key: 'PRON', token_type: 'implicit_pronoun', chapter_number: 1, verse_number: 5, word_number: nil,
      head_token_id: 2, rel_label: 'subj', rel_governor: 'مضارع',
      ref_token_position: 1,
      dependent_is_phrase: false, head_is_phrase: false,
      is_constituent: 0, constituent_span_start: nil, constituent_span_end: nil,
      constituent_label: nil, constituent_text: nil
    )
    payload = make_presenter(locale: 'ar', tokens: tokens).to_json_payload
    edges = payload[:sentences][0][:edges]

    subj_edge = edges.find { |e| e[:from] == 2 && e[:to] == 1 }
    assert subj_edge, "subj edge from pos 2 to pos 1 should exist"
    assert_equal 'فاعل مضارع', subj_edge[:label],
      "label should be base + governor: got #{subj_edge[:label].inspect}"
  end

  def test_ar_locale_labels
    payload = make_presenter(locale: 'ar').to_json_payload
    edges   = payload[:sentences][0][:edges]
    phrases = payload[:sentences][0][:phraseNodes]

    subj_edge = edges.find { |e| e[:relation] == 'subj' }
    assert subj_edge, "expected subj edge"
    assert_equal 'فاعل', subj_edge[:label]

    vs_node = phrases.find { |n| n[:labelKey] == 'VS' }
    assert vs_node, "expected VS phrase node"
    assert_equal 'جملة فعلية', vs_node[:label]
  end

  def test_en_locale_labels
    payload = make_presenter(locale: 'en').to_json_payload
    edges   = payload[:sentences][0][:edges]
    phrases = payload[:sentences][0][:phraseNodes]

    subj_edge = edges.find { |e| e[:relation] == 'subj' }
    assert subj_edge, "expected subj edge"
    assert_equal 'Subject', subj_edge[:label]

    vs_node = phrases.find { |n| n[:labelKey] == 'VS' }
    assert vs_node, "expected VS phrase node"
    assert_equal 'Verbal Sentence', vs_node[:label]
  end

  def test_verse_key
    payload = make_presenter(locale: 'en').to_json_payload
    assert_equal '1:5', payload[:verseKey]
  end

  def test_banner_text
    payload = make_presenter(locale: 'ar').to_json_payload
    banner = payload[:sentences][0][:banner]
    assert banner[:text].start_with?('﴿'), "banner text should start with ﴿"
    assert banner[:text].end_with?('﴾'), "banner text should end with ﴾"
  end

  def test_banner_includes_hidden_tokens_at_reading_position
    payload = make_presenter(locale: 'ar').to_json_payload
    banner = payload[:sentences][0][:banner]
    text = banner[:text]
    assert_includes text, '(نَحْنُ)', "banner must include implicit pronoun token at its reading position"
    inner = text[1..-2]
    parts = inner.split(' ')
    nahnu_indices = parts.each_index.select { |i| parts[i] == '(نَحْنُ)' }
    assert nahnu_indices.any?, "hidden token (نَحْنُ) must appear in banner"
    naabudo_idx = parts.index('نَعْبُدُ')
    assert naabudo_idx, "expected نَعْبُدُ in banner"
    assert nahnu_indices.first > naabudo_idx, "hidden pronoun should appear after its governor نَعْبُدُ in reading order"
  end

  def test_banner_reference_ar_single_verse
    payload = make_presenter(locale: 'ar').to_json_payload
    ref = payload[:sentences][0][:banner][:reference]
    assert_match 'الآية 5', ref
    assert_match 'الفاتحة', ref
  end

  def test_banner_reference_en_single_verse
    payload = make_presenter(locale: 'en').to_json_payload
    ref = payload[:sentences][0][:banner][:reference]
    assert_match 'Ayah 5', ref
    assert_match 'Al-Fatihah', ref
  end

  def test_edge_count
    payload = make_presenter(locale: 'en').to_json_payload
    edges = payload[:sentences][0][:edges]
    assert_equal 5, edges.size, "expected 5 edges (4 token-token + 1 phrase conj): got #{edges.map { |e| [e[:from], e[:to], e[:relation]] }}"
  end

  def test_token_count
    payload = make_presenter(locale: 'en').to_json_payload
    tokens = payload[:sentences][0][:tokens]
    assert_equal 7, tokens.size
  end
end
