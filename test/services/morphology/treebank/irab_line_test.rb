require_relative '../../../test_helper'

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
end unless defined?(Morphology::WordSegment::POS_TAG_COLORS)

require_relative '../../../../app/services/morphology/treebank/colors'
require_relative '../../../../app/services/morphology/treebank/irab_line'

class IrabLineTest < Minitest::Test
  AR = {
    'morphology.pos_tags.N'    => 'اسم',
    'morphology.pos_tags.V'    => 'فعل',
    'morphology.pos_tags.P'    => 'حرف جر',
    'morphology.pos_tags.PRON' => 'ضمير',
    'morphology.edge_relations.gen'  => 'مجرور',
    'morphology.edge_relations.subj' => 'فاعل',
    'morphology.edge_relations.obj'  => 'مفعول به',
    'morphology.edge_relations.root' => 'رأس الجملة',
  }.freeze

  def make_translator(dict = AR)
    lambda { |key, locale:, default:| dict[key] || default }
  end

  Token = Struct.new(
    :id, :pos_key, :prefix_type, :suffix_type, :verb_aspect, :derived_noun_type,
    :nominal_state, :verb_voice, :number, :gender, :person, :nominal_case,
    :verb_mood, :special_group, :lemma_name, :root_name, :verb_form,
    :rel_label, :rel_governor, :text_uthmani, :text_qpc_hafs,
    :token_type, :word_number, :position_in_word,
    keyword_init: true
  )

  def make_token(overrides = {})
    Token.new({
      id: 1,
      pos_key: 'N',
      prefix_type: nil,
      suffix_type: nil,
      verb_aspect: nil,
      derived_noun_type: nil,
      nominal_state: nil,
      verb_voice: nil,
      number: nil,
      gender: nil,
      person: nil,
      nominal_case: nil,
      verb_mood: nil,
      special_group: nil,
      lemma_name: nil,
      root_name: nil,
      verb_form: nil,
      rel_label: nil,
      rel_governor: nil,
      text_uthmani: 'اسْمِ',
      text_qpc_hafs: 'اسْمِ',
      token_type: 'surface',
      word_number: 2,
      position_in_word: 1
    }.merge(overrides))
  end

  def make_head_token(overrides = {})
    Token.new({
      id: 2,
      pos_key: 'P',
      prefix_type: 'bi+',
      suffix_type: nil,
      verb_aspect: nil,
      derived_noun_type: nil,
      nominal_state: nil,
      verb_voice: nil,
      number: nil,
      gender: nil,
      person: nil,
      nominal_case: nil,
      verb_mood: nil,
      special_group: nil,
      lemma_name: nil,
      root_name: nil,
      verb_form: nil,
      rel_label: 'root',
      rel_governor: nil,
      text_uthmani: 'بِ',
      text_qpc_hafs: 'بِ',
      token_type: 'surface',
      word_number: 2,
      position_in_word: 0
    }.merge(overrides))
  end

  def build_line(token, head_token, translator: nil)
    t = translator || make_translator
    Morphology::Treebank::IrabLine.new(token, head_token: head_token, translator: t)
  end

  def test_fragments_returns_array
    line = build_line(make_token, make_head_token)
    assert_instance_of Array, line.fragments
  end

  def test_pos_fragment_is_first_and_colored
    line = build_line(make_token(pos_key: 'N'), make_head_token)
    frags = line.fragments
    pos_frag = frags.first
    assert_equal 'اسم', pos_frag[:text]
    assert_equal 'sky', pos_frag[:color_class]
    assert_equal true, pos_frag[:arabic_font]
  end

  def test_lemma_fragment_present_when_lemma_name_given
    token = make_token(pos_key: 'N', lemma_name: 'اسْم')
    line = build_line(token, make_head_token)
    frags = line.fragments
    lead = frags.find { |f| f[:text] == '، اللما له «' }
    lemma = frags.find { |f| f[:text] == 'اسْم' && f[:color_class] == 'black' }
    assert lead, "expected lemma lead-in fragment"
    assert lemma, "expected lemma value fragment"
  end

  def test_root_fragment_present_when_root_name_given
    token = make_token(pos_key: 'N', root_name: 'سمو')
    line = build_line(token, make_head_token)
    frags = line.fragments
    lead = frags.find { |f| f[:text] == '، الجذر له «' }
    root = frags.find { |f| f[:text] == 'سمو' && f[:color_class] == 'black' }
    assert lead, "expected root lead-in fragment"
    assert root, "expected root value fragment"
  end

  def test_case_explanation_for_genitive_with_kasra
    token = make_token(pos_key: 'N', nominal_case: 'GEN', text_uthmani: 'اسْمِ')
    line = build_line(token, make_head_token)
    frags = line.fragments
    case_frag = frags.find { |f| f[:text].include?('مجرور') }
    assert case_frag, "expected genitive case explanation, got #{frags.map { |f| f[:text] }.inspect}"
    assert_equal 'مجرور وعلامة جره الكسره الظاهرة على اخره.', case_frag[:text]
  end

  def test_case_explanation_for_nominative_with_damma
    token = make_token(pos_key: 'N', nominal_case: 'NOM', text_uthmani: 'كِتَابُ')
    line = build_line(token, make_head_token)
    frags = line.fragments
    case_frag = frags.find { |f| f[:text].include?('مرفوع') }
    assert case_frag, "expected nominative case explanation, got #{frags.map { |f| f[:text] }.inspect}"
    assert_equal 'مرفوع وعلامة رفعه الضمة الظاهرة على اخره.', case_frag[:text]
  end

  def test_case_explanation_for_accusative_with_fatha
    token = make_token(pos_key: 'N', nominal_case: 'ACC', text_uthmani: 'كِتَابَ')
    line = build_line(token, make_head_token)
    frags = line.fragments
    case_frag = frags.find { |f| f[:text].include?('منصوب') }
    assert case_frag, "expected accusative case explanation"
    assert_equal 'منصوب وعلامة نصبه الفتحة الظاهرة على اخره.', case_frag[:text]
  end

  def test_dependency_clause_for_normal_head
    token = make_token(pos_key: 'N', rel_label: 'gen', nominal_case: 'GEN', text_uthmani: 'اسْمِ')
    head = make_head_token(pos_key: 'P', text_qpc_hafs: 'بِ', token_type: 'surface')
    line = build_line(token, head)
    frags = line.fragments
    dep_lead = frags.find { |f| f[:text] == '. وهو ' }
    assert dep_lead, "expected dependency clause lead '. وهو '"
    head_ref = frags.find { |f| f[:text] == 'بِ' && f[:color_class] == 'green' }
    assert head_ref, "expected green head text reference"
  end

  def test_dependency_clause_implicit_pronoun_head_masculine
    token = make_token(pos_key: 'N', rel_label: 'subj')
    head = make_head_token(pos_key: 'V', text_qpc_hafs: '(نَحْنُ)', token_type: 'implicit_pronoun')
    line = build_line(token, head)
    frags = line.fragments
    hidden = frags.find { |f| f[:text] == 'المحذوف' }
    assert hidden, "expected المحذوف for implicit-pronoun head, got #{frags.map { |f| f[:text] }.inspect}"
  end

  def test_dependency_clause_elided_head_feminine_pos
    token = make_token(pos_key: 'N', rel_label: 'subj')
    dict = AR.merge('morphology.pos_tags.PRON' => 'ضميرة')
    head = make_head_token(pos_key: 'PRON', text_qpc_hafs: '(هِيَ)', token_type: 'elided')
    line = build_line(token, head, translator: make_translator(dict))
    frags = line.fragments
    hidden = frags.find { |f| f[:text] == 'المحذوفة' }
    assert hidden, "expected المحذوفة when head POS Arabic label ends with ة, got #{frags.map { |f| f[:text] }.inspect}"
  end

  def test_prefix_fragment_in_guillemets
    token = make_token(pos_key: 'P', prefix_type: 'bi+')
    line = build_line(token, make_head_token)
    frags = line.fragments
    open = frags.find { |f| f[:text] == ' «' }
    close = frags.find { |f| f[:text] == '»' }
    assert open, "expected opening guillemet for prefix"
    assert close, "expected closing guillemet for prefix"
  end

  def test_dependency_clause_compound_head_pos_label
    token = make_token(pos_key: 'N', rel_label: 'gen', nominal_case: 'GEN', text_uthmani: 'اسْمِ')
    head = make_head_token(pos_key: 'P', text_qpc_hafs: 'بِ', token_type: 'surface')
    line = build_line(token, head)
    frags = line.fragments
    compound_frag = frags.find { |f| f[:text].include?('ال‍') && f[:text].include?('جر') }
    assert compound_frag, "expected compound head POS fragment with ال‍-joined second word, got #{frags.map { |f| f[:text] }.inspect}"
    assert_equal 'حرف ال‍جر', compound_frag[:text]
  end

  def test_no_dependency_clause_when_rel_label_blank
    token = make_token(pos_key: 'N', rel_label: nil)
    line = build_line(token, nil)
    frags = line.fragments
    dep_frag = frags.find { |f| f[:text] == '. وهو ' }
    refute dep_frag, "no dependency clause expected when rel_label is nil"
  end

  def test_no_case_explanation_when_nominal_case_and_verb_mood_absent
    token = make_token(pos_key: 'N', nominal_case: nil, verb_mood: nil, text_uthmani: 'كِتَابُ')
    line = build_line(token, nil)
    frags = line.fragments
    case_frag = frags.find { |f| f[:text].include?('مرفوع') || f[:text].include?('مجرور') || f[:text].include?('منصوب') || f[:text].include?('مجزوم') }
    refute case_frag, "no case explanation when nominal_case and verb_mood both nil"
  end
end
