require 'minitest/autorun'
require_relative '../../../lib/audio_segment/ayah_gap_filler'

class AyahGapFillerTest < Minitest::Test
  def fill(ranges)
    AudioSegment::AyahGapFiller.call(ranges)
  end

  def test_long_pause_goes_to_previous_ayah
    # 5 s pause: the next ayah keeps 200 ms, the previous ayah takes the rest.
    assert_equal [[0, 9800], [9800, 15_000]], fill([[0, 5000], [10_000, 15_000]])
  end

  def test_short_gap_goes_to_next_ayah
    assert_equal [[0, 5000], [5000, 9000]], fill([[0, 5000], [5150, 9000]])
  end

  def test_gap_of_exactly_lead_goes_to_next_ayah
    assert_equal [[0, 5000], [5000, 9000]], fill([[0, 5000], [5200, 9000]])
  end

  def test_touching_and_overlapping_ayahs_unchanged
    assert_equal [[0, 5000], [5000, 9000], [8800, 12_000]],
                 fill([[0, 5000], [5000, 9000], [8800, 12_000]])
  end

  def test_first_start_and_last_end_unchanged
    assert_equal [[1440, 7800], [7800, 13_380]], fill([[1440, 7340], [8000, 13_380]])
  end

  def test_each_gap_handled_on_its_own
    assert_equal [[0, 2800], [2800, 4800], [4800, 7000]],
                 fill([[0, 1000], [3000, 4000], [5000, 7000]])
  end

  def test_input_not_mutated_and_empty_surah_ok
    ranges = [[0, 1000], [3000, 4000]]
    fill(ranges)
    assert_equal [[0, 1000], [3000, 4000]], ranges
    assert_equal [], fill([])
  end
end
