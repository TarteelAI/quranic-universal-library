require 'minitest/autorun'
require_relative '../../../app/services/audio/segment_repetition'

class SegmentRepetitionTest < Minitest::Test
  R = Audio::SegmentRepetition

  # Recitation 175, surah 70: 27, 28, then 27 and 28 again.
  AYAH_27 = [[1, 148225, 149365], [2, 149365, 150455], [3, 150455, 150755], [4, 150755, 151645],
             [5, 151645, 152955], [6, 152955, 155605],
             [1, 163980, 165040], [2, 165040, 165710], [3, 165710, 165970], [4, 165970, 166800],
             [5, 166800, 168820], [6, 168820, 170460]].freeze
  AYAH_28 = [[1, 156020, 157940], [2, 157940, 158930], [3, 158930, 159840], [4, 159840, 160550],
             [5, 160550, 163210],
             [1, 170860, 172090], [2, 172090, 172920], [3, 172920, 173910], [4, 173910, 174570],
             [5, 174570, 177170]].freeze
  AYAH_29 = [[1, 177550, 178800], [2, 178800, 179200]].freeze

  def returns
    @returns ||= R.cross_ayah_returns([[27, AYAH_27], [28, AYAH_28], [29, AYAH_29]])
  end

  def test_finds_each_return_and_the_ayahs_recited_in_between
    assert_equal [{ after_word: 6, back_to_word: 1, gap_from: 155605, gap_to: 163980, ayahs: [28] }], returns[27]
    assert_equal [27], returns[28].first[:ayahs]
    assert_equal 170860, returns[28].first[:gap_to]
    assert_nil returns[29]
  end

  def test_a_pause_inside_an_ayah_is_not_a_return
    pause = [[1, 0, 1000], [2, 5000, 6000]]
    assert_empty R.cross_ayah_returns([[1, pause], [2, [[1, 7000, 8000]]]])
  end

  def test_splits_the_word_list_at_each_return
    first, again = R.split_passes(AYAH_27, returns[27])
    assert_equal AYAH_27.first(6), first
    assert_equal AYAH_27.last(6), again
    assert_equal [AYAH_29], R.split_passes(AYAH_29, nil)
  end

  def test_a_return_is_not_also_a_repeat_inside_the_ayah
    assert_equal [[1, 6]], R.within_repeats(AYAH_27)
    assert_empty R.within_repeats_by_pass(AYAH_27, returns[27])
  end

  def test_repeats_inside_the_ayah
    words = [1, 2, 3, 4, 5, 3, 4, 5, 6].each_with_index.map { |w, i| [w, i * 100, i * 100 + 100] }
    assert_equal [[3, 5]], R.within_repeats(words)
  end

  def test_alternating_takes_are_one_repeat_not_backwards_runs
    words = [1, 2, 1, 2, 1, 2].each_with_index.map { |w, i| [w, i * 100, i * 100 + 100] }
    assert_equal [[1, 2]], R.within_repeats(words)
  end
end
