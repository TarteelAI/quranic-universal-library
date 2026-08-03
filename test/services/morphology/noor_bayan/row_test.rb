require_relative '../../../test_helper'
require_relative '../../../../lib/corpus/morphology/unsupported_operation_exception'
require_relative '../../../../lib/corpus/morphology/part_of_speech'
require_relative '../../../../lib/corpus/morphology/form_type'
require_relative '../../../../lib/corpus/morphology/aspect_type'
require_relative '../../../../lib/corpus/morphology/mood_type'
require_relative '../../../../lib/corpus/morphology/voice_type'
require_relative '../../../../lib/corpus/morphology/case_type'
require_relative '../../../../lib/corpus/morphology/state_type'
require_relative '../../../../lib/corpus/morphology/person_type'
require_relative '../../../../lib/corpus/morphology/gender_type'
require_relative '../../../../lib/corpus/morphology/number_type'
require_relative '../../../../app/services/morphology/noor_bayan/governors'
require_relative '../../../../app/services/morphology/noor_bayan/row'

class NoorBayanRowTest < Minitest::Test
  def base_row(overrides = {})
    {
      'tid' => '2', 'sentence_id' => '1', 'sentence_word' => '1', 'token_id' => '2',
      'location' => '(1:1:1:2)', 'chapter_id' => '1', 'verse_id' => '1',
      'word_id' => '1', 'tok_id' => '2',
      'uthmani_token' => 'سْمِ', 'uthmani_unicode' => 'somi',
      'imlaai_token' => 'سْم', 'imlaai_unicode' => 'som',
      'phonetic' => "bis'mi", 'trans' => 'In (the) name',
      'pos' => 'N', 'pos_ar' => 'اسم', 're_uthmani' => 'بِ', 'rpos' => 'حرف جر',
      'features' => 'STEM|POS:N|LEM:{som|ROOT:smw|M|GEN',
      'segment' => 'STEM', 'lemma' => '{som', 'lemma_ar' => 'ٱسْم',
      'root' => 'smw', 'root_ar' => 'سمو',
      'verb_form' => '_', 'prefix' => '_', 'suffix' => '_',
      'verb_aspect' => '_', 'nominal_state' => '_', 'verb_mood' => '_',
      'special_group' => '_', 'nominal_case' => 'GEN', 'derived_nouns' => '_',
      'verb_voice' => '_', 'pgn' => 'M', 'person' => '_', 'gender' => 'M', 'number' => '_',
      'rel_label' => 'gen', 'rel_label_ar' => 'مجرور', 'ref_token_id' => '1',
      'is_constituent' => '0', 'constituents_loc' => '_', 'constituents' => '_',
      'constituent_label' => '-', 'constituent_label_en' => '-',
      'loc1' => '_', 'depend_rel' => '0', 'head_rel' => '0', 'FID' => '3'
    }.merge(overrides)
  end

  def test_surface_token_attributes
    row = Morphology::NoorBayan::Row.new(base_row)
    attrs = row.attributes

    assert_equal 'surface', row.token_type
    assert_equal 1, row.sentence_number
    assert_equal '1:1:1', row.word_location
    assert_equal '1:1:1:2', attrs[:location]
    assert_equal 1, attrs[:chapter_number]
    assert_equal 1, attrs[:verse_number]
    assert_equal 1, attrs[:word_number]
    assert_equal 2, attrs[:position_in_word]
    assert_equal 2, attrs[:position_in_sentence]
    assert_equal 'سْمِ', attrs[:text_uthmani]
    assert_equal 'N', attrs[:pos_key]
    assert_equal 'Stem', attrs[:segment_type]
    assert_equal 'ٱسْم', attrs[:lemma_name]
    assert_equal 'سمو', attrs[:root_name]
    assert_equal 'GEN', attrs[:nominal_case]
    assert_equal 'gen', attrs[:rel_label]
    assert_nil attrs[:rel_governor]
    assert_equal 1, attrs[:ref_token_position]
    assert_nil attrs[:verb_form]
    assert_equal 'somi', attrs[:source_meta][:buckwalter]
    assert_equal '{som', attrs[:source_meta][:lemma_bw]
    assert_equal 'smw', attrs[:source_meta][:root_bw]
    assert_equal 'مجرور', attrs[:source_meta][:rel_label_ar]
  end

  def test_placeholders_become_nil
    row = Morphology::NoorBayan::Row.new(base_row('lemma_ar' => 'ـ', 'phonetic' => '_'))
    attrs = row.attributes

    assert_nil attrs[:lemma_name]
    assert_nil attrs[:phonetic]
  end

  def test_elided_token
    row = Morphology::NoorBayan::Row.new(
      base_row('uthmani_token' => '(*)', 'location' => '_', 'word_id' => '0')
    )

    assert_equal 'elided', row.token_type
    assert_nil row.word_location
    assert_nil row.attributes[:location]
    assert_nil row.attributes[:word_number]
  end

  def test_implicit_pronoun_token
    row = Morphology::NoorBayan::Row.new(
      base_row('uthmani_token' => '(نحْنُ)', 'location' => '_', 'word_id' => '0', 'pos' => 'PRON')
    )

    assert_equal 'implicit_pronoun', row.token_type
    assert_equal '(نحْنُ)', row.attributes[:text_uthmani]
  end

  def test_tag_normalization
    row = Morphology::NoorBayan::Row.new(
      base_row(
        'verb_form' => '(IV)', 'verb_mood' => 'MOOD:JUS', 'special_group' => 'SP:kaAn',
        'segment' => 'PREFIX', 'derived_nouns' => 'ACT_PCPL'
      )
    )
    attrs = row.attributes

    assert_equal 'IV', attrs[:verb_form]
    assert_equal 'JUS', attrs[:verb_mood]
    assert_equal 'kana', attrs[:special_group]
    assert_equal 'Prefix', attrs[:segment_type]
    assert_equal 'ACT PCPL', attrs[:derived_noun_type]
  end

  def test_rel_label_governor_split
    row = Morphology::NoorBayan::Row.new(
      base_row('rel_label' => 'pred <<kan>>', 'rel_label_ar' => 'خبر كان')
    )

    assert_equal 'pred', row.attributes[:rel_label]
    assert_equal 'كان', row.attributes[:rel_governor]

    row = Morphology::NoorBayan::Row.new(
      base_row('rel_label' => 'subj<<in>>', 'rel_label_ar' => 'اسم إن')
    )

    assert_equal 'subj', row.attributes[:rel_label]
    assert_equal 'إنّ', row.attributes[:rel_governor]
  end

  def test_rel_label_is_lowercased
    row = Morphology::NoorBayan::Row.new(base_row('rel_label' => 'Subj'))

    assert_equal 'subj', row.attributes[:rel_label]
  end

  def test_constituency_fields
    row = Morphology::NoorBayan::Row.new(
      base_row(
        'is_constituent' => '1', 'constituents_loc' => '[1-2]',
        'constituents' => 'بِسْمِ', 'constituent_label' => 'PP', 'constituent_label_en' => 'PP',
        'depend_rel' => '1', 'head_rel' => '0'
      )
    )
    attrs = row.attributes

    assert_equal 1, attrs[:is_constituent]
    assert_equal 1, attrs[:constituent_span_start]
    assert_equal 2, attrs[:constituent_span_end]
    assert_equal 'بِسْمِ', attrs[:constituent_text]
    assert_equal 'PP', attrs[:constituent_label]
    assert attrs[:dependent_is_phrase]
    refute attrs[:head_is_phrase]
  end

  def test_qpc_hafs_conversion
    row = Morphology::NoorBayan::Row.new(base_row('uthmani_token' => 'سْمِ'))

    assert_equal 'سۡمِ', row.attributes[:text_qpc_hafs]
  end

  def test_unknown_pos_raises
    assert_raises(Corpus::Morphology::UnsupportedOperationException) do
      Morphology::NoorBayan::Row.new(base_row('pos' => 'BOGUS')).attributes
    end
  end
end
