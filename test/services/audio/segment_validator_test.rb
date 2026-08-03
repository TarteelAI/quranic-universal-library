require 'minitest/autorun'
require_relative '../../../app/services/audio/segment_validator'

class SegmentValidatorTest < Minitest::Test
  Data = Audio::SegmentValidator::SegmentData

  def segment(chapter: 32, verse:, from:, to:, words: nil, words_count: nil, audio_file_id: 1, audio_duration_ms: nil)
    words ||= [[1, from, to]]
    words_count ||= words.size
    Data.new(
      verse_key: "#{chapter}:#{verse}",
      chapter_id: chapter,
      verse_number: verse,
      timestamp_from: from,
      timestamp_to: to,
      words_count: words_count,
      word_segments: words,
      audio_file_id: audio_file_id,
      audio_duration_ms: audio_duration_ms
    )
  end

  def validate(segments, expected: nil)
    Audio::SegmentValidator.new(segments, expected_verses_count: expected || segments.size).validate
  end

  def categories(issues)
    issues.map { |issue| issue[:category] }
  end

  # --- The exact case reported for recitation 1, surah 32 -------------------

  def test_flags_the_three_reported_ayah_overlaps
    segments = [
      segment(verse: 1, from: 0, to: 14047),
      segment(verse: 2, from: 8947, to: 20000),
      segment(verse: 3, from: 21000, to: 40000),
      segment(verse: 4, from: 41000, to: 132475),
      segment(verse: 5, from: 130961, to: 140000)
    ]

    issues = validate(segments)
    overlaps = issues.select { |issue| issue[:category] == 'ayah_overlap' }

    assert_equal ['32:1', '32:4'], overlaps.map { |issue| issue[:key] }
    assert_includes overlaps.first[:text], 'overlaps the next ayah 32:2 starting at 8947'
  end

  # --- Ayah-level rules -----------------------------------------------------

  def test_overlap_is_danger
    segments = [
      segment(verse: 1, from: 0, to: 5000),
      segment(verse: 2, from: 4000, to: 8000)
    ]
    overlap = validate(segments).find { |issue| issue[:category] == 'ayah_overlap' }

    refute_nil overlap
    assert_equal 'bg-danger', overlap[:severity]
    assert_equal '32:1', overlap[:key]
  end

  def test_gap_larger_than_threshold_is_warning
    segments = [
      segment(verse: 1, from: 0, to: 5000),
      segment(verse: 2, from: 8000, to: 10000)
    ]
    gap = validate(segments).find { |issue| issue[:category] == 'ayah_gap' }

    refute_nil gap
    assert_equal 'bg-warning', gap[:severity]
  end

  def test_gap_within_threshold_is_ignored
    segments = [
      segment(verse: 1, from: 0, to: 5000),
      segment(verse: 2, from: 6500, to: 10000)
    ]
    assert_empty validate(segments).select { |issue| issue[:category] == 'ayah_gap' }
  end

  def test_missing_timestamps
    segments = [segment(verse: 1, from: nil, to: 5000)]
    issue = validate(segments).find { |issue| issue[:category] == 'ayah_timing' }
    assert_includes issue[:text], 'timestamp from OR to is missing'
  end

  def test_to_less_than_from
    segments = [segment(verse: 1, from: 5000, to: 4000)]
    issue = validate(segments).find { |issue| issue[:category] == 'ayah_timing' }
    assert_includes issue[:text], 'less than timestamp from'
  end

  def test_zero_duration
    segments = [segment(verse: 1, from: 5000, to: 5000)]
    issue = validate(segments).find { |issue| issue[:category] == 'ayah_timing' }
    assert_includes issue[:text], 'duration is 0'
  end

  def test_ayah_starts_after_first_word
    segments = [segment(verse: 1, from: 1000, to: 5000, words: [[1, 500, 900]])]
    issue = validate(segments).find { |issue| issue[:category] == 'ayah_timing' }
    assert_includes issue[:text], 'after its earliest word'
  end

  def test_ayah_starts_after_its_earliest_word_even_when_word_one_is_misplaced
    words = [[2, 170240, 170590], [1, 175451, 177154]]
    segments = [segment(verse: 1, from: 175451, to: 177154, words: words, words_count: 2)]
    issue = validate(segments).find { |issue| issue[:category] == 'ayah_timing' && issue[:text].include?('earliest') }

    refute_nil issue
    assert_equal 'bg-danger', issue[:severity]
  end

  def test_ayah_ends_before_its_latest_word
    words = [[1, 0, 100], [2, 100, 5000]]
    segments = [segment(verse: 1, from: 0, to: 3000, words: words, words_count: 2)]
    issue = validate(segments).find { |issue| issue[:category] == 'ayah_timing' && issue[:text].include?('latest') }

    refute_nil issue
    assert_equal 'bg-warning', issue[:severity]
  end

  def test_ayah_overlap_detected_via_next_ayah_actual_word_start
    prev_words = [[1, 168000, 172628]]
    next_words = [
      [2, 170240, 170590], [3, 170640, 172430], [4, 172480, 173150],
      [5, 173200, 174630], [6, 174680, 175451], [1, 175451, 177154]
    ]
    segments = [
      segment(chapter: 68, verse: 23, from: 168000, to: 172628, words: prev_words, words_count: 1),
      segment(chapter: 68, verse: 24, from: 175451, to: 177154, words: next_words, words_count: 6)
    ]
    overlap = validate(segments).find { |issue| issue[:category] == 'ayah_overlap' }

    refute_nil overlap
    assert_equal 'bg-danger', overlap[:severity]
    assert_equal '68:23', overlap[:key]
  end

  # --- Word order / repeat completeness -------------------------------------

  def test_reported_misordered_word_one_is_flagged
    words = [
      [2, 170240, 170590], [3, 170640, 172430], [4, 172480, 173150],
      [5, 173200, 174630], [6, 174680, 175451], [1, 175451, 177154]
    ]
    segments = [segment(chapter: 68, verse: 24, from: 170240, to: 177154, words: words, words_count: 6)]
    issue = validate(segments).find { |issue| issue[:category] == 'word_order' }

    refute_nil issue
    assert_equal 'bg-danger', issue[:severity]
  end

  def test_word_order_must_start_at_word_one
    words = [[2, 100, 200], [3, 200, 300]]
    segments = [segment(verse: 1, from: 100, to: 300, words: words, words_count: 3)]
    issue = validate(segments).find { |issue| issue[:category] == 'word_order' && issue[:text].include?('start at word 1') }

    refute_nil issue
    assert_equal 'bg-danger', issue[:severity]
  end

  def test_word_order_must_end_at_last_word
    words = [[1, 0, 100], [2, 100, 200], [1, 200, 300]]
    segments = [segment(verse: 1, from: 0, to: 300, words: words, words_count: 3)]
    issue = validate(segments).find { |issue| issue[:category] == 'word_order' && issue[:text].include?('incomplete') }

    refute_nil issue
    assert_equal 'bg-danger', issue[:severity]
  end

  def test_word_order_every_word_must_appear
    words = [[1, 0, 100], [2, 100, 200], [4, 200, 300]]
    segments = [segment(verse: 1, from: 0, to: 300, words: words, words_count: 4)]
    issue = validate(segments).find { |issue| issue[:category] == 'word_order' && issue[:text].include?('no segment for word') }

    refute_nil issue
    assert_includes issue[:text], '3'
  end

  def test_word_order_run_must_be_contiguous
    words = [[1, 0, 100], [2, 100, 200], [4, 200, 300], [3, 300, 400], [4, 400, 500]]
    segments = [segment(verse: 1, from: 0, to: 500, words: words, words_count: 4)]
    issue = validate(segments).find { |issue| issue[:category] == 'word_order' && issue[:text].include?('jump') }

    refute_nil issue
    assert_equal 'bg-danger', issue[:severity]
  end

  def test_valid_repeat_is_allowed
    words = [
      [1, 0, 100], [2, 100, 200], [3, 200, 300], [4, 300, 400], [5, 400, 500],
      [2, 500, 600], [3, 600, 700], [4, 700, 800], [5, 800, 900], [6, 900, 1000]
    ]
    segments = [segment(verse: 1, from: 0, to: 1000, words: words, words_count: 6)]

    assert_empty validate(segments).select { |issue| issue[:category] == 'word_order' }
  end

  def test_missing_ayah_count
    segments = [segment(verse: 1, from: 0, to: 5000)]
    issue = validate(segments, expected: 30).find { |issue| issue[:category] == 'missing_segments' }

    refute_nil issue
    assert_includes issue[:text], "29 ayahs don't have segments data"
  end

  # --- Word-level rules -----------------------------------------------------

  def test_missing_words
    segments = [segment(verse: 1, from: 0, to: 5000, words: [[1, 0, 2000]], words_count: 3)]
    issue = validate(segments).find { |issue| issue[:category] == 'missing_words' }

    refute_nil issue
    assert_includes issue[:text], '2 words missing'
  end

  def test_word_overlap
    words = [[1, 0, 3000], [2, 2000, 4000]]
    segments = [segment(verse: 1, from: 0, to: 4000, words: words, words_count: 2)]
    issue = validate(segments).find { |issue| issue[:category] == 'word_overlap' }

    refute_nil issue
    assert_includes issue[:text], 'words overlap'
  end

  def test_word_past_audio_duration
    words = [[1, 0, 9000]]
    segments = [segment(verse: 1, from: 0, to: 9000, words: words, audio_duration_ms: 8000)]
    issue = validate(segments).find { |issue| issue[:category] == 'word_past_duration' }

    refute_nil issue
    assert_includes issue[:text], 'past the audio duration'
  end

  def test_word_zero_duration
    words = [[1, 100, 100]]
    segments = [segment(verse: 1, from: 100, to: 5000, words: words)]
    issue = validate(segments).find { |issue| issue[:category] == 'word_timing' }
    assert_includes issue[:text], 'Word duration is 0'
  end

  # --- File-level rules -----------------------------------------------------

  def test_trailing_gap
    segments = [segment(verse: 1, from: 0, to: 5000, audio_duration_ms: 20000)]
    issue = validate(segments).find { |issue| issue[:category] == 'trailing_gap' }

    refute_nil issue
    assert_equal 'bg-danger', issue[:severity]
    assert_includes issue[:text], 'unsegmented'
  end

  def test_trailing_gap_within_threshold_is_ignored
    segments = [segment(verse: 1, from: 0, to: 5000, audio_duration_ms: 5500)]
    assert_empty validate(segments).select { |issue| issue[:category] == 'trailing_gap' }
  end

  def test_clean_data_has_no_issues
    segments = [
      segment(verse: 1, from: 0, to: 5000, words: [[1, 0, 5000]], audio_duration_ms: 9200),
      segment(verse: 2, from: 5100, to: 9000, words: [[1, 5100, 9000]], audio_duration_ms: 9200)
    ]
    assert_empty validate(segments)
  end
end
