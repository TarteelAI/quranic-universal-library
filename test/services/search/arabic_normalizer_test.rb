require 'minitest/autorun'
require_relative '../../../app/services/search/arabic_normalizer'

class ArabicNormalizerTest < Minitest::Test
  FA_ILAHUKUM = "فَإِلَٰهُكُمۡ"
  FA_ILAHUKUM_SKELETON = "فالهكم"

  def test_strips_tashkeel_and_quranic_marks
    assert_equal FA_ILAHUKUM_SKELETON, Search::ArabicNormalizer.normalize(FA_ILAHUKUM)
  end

  def test_unifies_alef_variants
    assert_equal "اااا", Search::ArabicNormalizer.normalize("أإآٱ")
  end

  def test_unifies_ya_ta_marbuta_and_hamza_carriers
    assert_equal "يهوي", Search::ArabicNormalizer.normalize("ىةؤئ")
  end

  def test_strips_tatweel
    assert_equal "كتاب", Search::ArabicNormalizer.normalize("كـتاب")
  end

  def test_is_idempotent
    once = Search::ArabicNormalizer.normalize(FA_ILAHUKUM)
    assert_equal once, Search::ArabicNormalizer.normalize(once)
  end

  def test_handles_nil
    assert_equal '', Search::ArabicNormalizer.normalize(nil)
  end

  def test_normalizes_unicode_spaces_to_regular_space
    input = [0x627, 0x644, 0x644, 0x647, 0x00A0, 0x627, 0x644, 0x635, 0x645, 0x62F].pack('U*')
    assert_equal "الله الصمد", Search::ArabicNormalizer.normalize(input)
  end

  def test_strips_zero_width_and_directional_marks
    input = [0x627, 0x644, 0x635, 0x200C, 0x645, 0x62F, 0x200F].pack('U*')
    assert_equal "الصمد", Search::ArabicNormalizer.normalize(input)
  end

  def test_normalize_with_map_returns_skeleton_and_index_map
    normalized, map = Search::ArabicNormalizer.normalize_with_map(FA_ILAHUKUM)

    assert_equal FA_ILAHUKUM_SKELETON, normalized
    assert_equal FA_ILAHUKUM_SKELETON.length, map.length
    assert_equal 0, map.first[0]
    assert_equal FA_ILAHUKUM.length, map.last[1]
  end

  def test_normalize_with_map_attaches_trailing_marks_to_previous_letter
    normalized, map = Search::ArabicNormalizer.normalize_with_map(FA_ILAHUKUM)

    second_letter_slice = FA_ILAHUKUM[map[1][0]...map[1][1]]
    assert_equal "إِ", second_letter_slice
    assert_equal normalized.length, map.length
  end
end
