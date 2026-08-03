require_relative '../../test_helper'
require_relative '../../../lib/corpus/morphology/unsupported_operation_exception'
require_relative '../../../lib/corpus/morphology/aspect_type'
require_relative '../../../lib/corpus/morphology/case_type'
require_relative '../../../lib/corpus/morphology/form_type'
require_relative '../../../lib/corpus/morphology/derivation_type'
require_relative '../../../lib/corpus/morphology/gender_type'
require_relative '../../../lib/corpus/morphology/number_type'
require_relative '../../../lib/corpus/morphology/voice_type'
require_relative '../../../lib/corpus/morphology/state_type'
require_relative '../../../lib/corpus/morphology/special_group_type'

class MorphologyTypesTest < Minitest::Test
  def test_new_types_have_expected_tags
    assert_equal %w[ACT PASS], Corpus::Morphology::VoiceType.all.map(&:tag)
    assert_equal %w[DEF INDEF], Corpus::Morphology::StateType.all.map(&:tag)
    assert_equal %w[kana inna kada], Corpus::Morphology::SpecialGroupType.all.map(&:tag)
  end

  def test_parse_returns_the_matching_type
    assert_equal 'PASS', Corpus::Morphology::VoiceType.parse('PASS').tag
    assert_equal 'PERF', Corpus::Morphology::AspectType.parse('PERF').tag
    assert_equal 'GEN', Corpus::Morphology::CaseType.parse('GEN').tag
    assert_equal 'IV', Corpus::Morphology::FormType.parse('IV').tag
    assert_equal 'ACT PCPL', Corpus::Morphology::DerivationType.parse('ACT PCPL').tag
    assert_equal 'M', Corpus::Morphology::GenderType.parse('M').tag
    assert_equal 'P', Corpus::Morphology::NumberType.parse('P').tag
    assert_equal 'inna', Corpus::Morphology::SpecialGroupType.parse('inna').tag
  end

  def test_parse_raises_on_unknown_tag
    assert_raises(Corpus::Morphology::UnsupportedOperationException) do
      Corpus::Morphology::AspectType.parse('BOGUS')
    end
  end
end
