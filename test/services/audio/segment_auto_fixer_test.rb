require 'minitest/autorun'
require 'ostruct'
require_relative '../../../app/services/audio/segment_validator'
require_relative '../../../app/services/audio/segment_auto_fixer'

class SegmentAutoFixerTest < Minitest::Test
  class FakeSegment
    attr_accessor :chapter_id, :verse_number, :timestamp_from, :timestamp_to,
                  :segments, :segments_count, :audio_file_id

    def initialize(chapter_id: 32, verse_number:, from:, to:, words:, words_count: nil, audio_file_id: 1, audio_duration_ms: nil)
      @chapter_id = chapter_id
      @verse_number = verse_number
      @timestamp_from = from
      @timestamp_to = to
      @segments = words
      @segments_count = words.size
      @words_count = words_count || words.size
      @audio_file_id = audio_file_id
      @audio_duration_ms = audio_duration_ms
      @changed = false
    end

    def verse_key
      "#{chapter_id}:#{verse_number}"
    end

    def verse
      self
    end

    def words_count
      @words_count
    end

    def get_segments(drop_metadata: false)
      @segments.map { |word| [word[0], word[1], word[2]] }
    end

    def audio_file
      @audio_duration_ms ? OpenStruct.new(duration_ms: @audio_duration_ms) : nil
    end

    def set_timing(from, to, _verse)
      @timestamp_from = from.to_i
      @timestamp_to = to.to_i
      @changed = true
    end

    def segments=(list)
      @segments = list
      @changed = true
    end

    def changed?
      @changed
    end
  end

  def run_fixer(segments)
    Audio::SegmentAutoFixer.new(segments, expected_verses_count: segments.size).run
  end

  def test_corrects_following_start_when_word_gap_exceeds_threshold
    # Mirrors 38:59/38:60: large gap between last word and first word of next ayah (> 2000ms),
    # but words are still sequential — fix applies regardless of gap size.
    # a.to = 1516200 exceeds new_following_from (1516100) so the residual-overlap trim also fires.
    a = FakeSegment.new(verse_number: 59, from: 1400000, to: 1516200, words: [[1, 1400000, 1513000]])
    b = FakeSegment.new(verse_number: 60, from: 1017408, to: 1530000, words: [[1, 1516500, 1530000]], words_count: 1)

    result = run_fixer([a, b])

    assert_equal 1516100, b.timestamp_from  # 1516500 - 400ms buffer
    assert_equal 1516099, a.timestamp_to    # trimmed to b.from - 1
    assert_equal 1, result.fixed['ayah_overlap']
    assert_equal 0, result.after['ayah_overlap'].to_i
  end

  def test_fixes_when_first_word_start_equals_current_end
    # Strict `>` was failing when first_word_start == current_to exactly.
    # last_word_end (6014000) > first_word_start (6013926) so the first condition fails;
    # only the second condition `>= current_to` can make words_sequential true here.
    a = FakeSegment.new(verse_number: 115, from: 5990000, to: 6013926, words: [[1, 5990000, 6014000]])
    b = FakeSegment.new(verse_number: 116, from: 5969284, to: 6030000, words: [[1, 6013926, 6030000]], words_count: 1)

    result = run_fixer([a, b])

    # new_following_from = 6013926 - 400 = 6013526 (else branch: first_word_start < last_word_end)
    assert_equal 6013526, b.timestamp_from
    assert_equal 6013525, a.timestamp_to  # trimmed to b.from - 1
    assert_equal 1, result.fixed['ayah_overlap']
    assert_equal 0, result.after['ayah_overlap'].to_i
  end

  def test_fixes_when_first_word_starts_after_current_end_despite_overlapping_last_word_time
    # The exact failure mode for 38:59/38:60:
    # a's last word end (1516000) > b's first word start (1515600) → old `>= last_word_end` fails.
    # But b's first word (1515600) > a.timestamp_to (1515500) → new condition catches it.
    a = FakeSegment.new(verse_number: 59, from: 1400000, to: 1515500, words: [[1, 1400000, 1516000]])
    b = FakeSegment.new(verse_number: 60, from: 1017408, to: 1030000, words: [[1, 1515600, 1528000]], words_count: 1)

    result = run_fixer([a, b])

    assert_equal 1515200, b.timestamp_from  # first_word_start (1515600) - 400ms buffer
    assert_equal 1528000, b.timestamp_to    # derived from b's last word (to was also wrong)
    assert_equal 1515199, a.timestamp_to    # trimmed to b.from - 1
    assert_equal 1, result.fixed['ayah_overlap']
    assert_equal 0, result.after['ayah_overlap'].to_i
  end

  def test_corrects_following_start_and_end_when_both_timestamps_are_wrong
    # Mirrors 38:59/38:60: both timestamp_from AND timestamp_to of following are wrong (early).
    # The smart fix falls back to last word's end time for effective_to.
    a = FakeSegment.new(verse_number: 59, from: 1400000, to: 1515500, words: [[1, 1400000, 1515000]])
    b = FakeSegment.new(verse_number: 60, from: 1017408, to: 1030000, words: [[1, 1515600, 1528000]], words_count: 1)

    result = run_fixer([a, b])

    assert_equal 1515200, b.timestamp_from  # 1515600 - 400ms buffer
    assert_equal 1528000, b.timestamp_to    # derived from last word end time
    assert_equal 1515199, a.timestamp_to    # trimmed to b.from - 1
    assert_equal 1, result.fixed['ayah_overlap']
    assert_equal 0, result.after['ayah_overlap'].to_i
  end

  def test_corrects_following_ayah_start_when_overlap_caused_by_bad_timestamp
    # Mirrors 23:22/23:23: following.timestamp_from is too early but its first word starts
    # after current's last word ends — fix by moving following's start and trimming current's end.
    a = FakeSegment.new(verse_number: 22, from: 400000, to: 476079, words: [[1, 400000, 475407]])
    b = FakeSegment.new(verse_number: 23, from: 448562, to: 520000, words: [[1, 476080, 520000]], words_count: 1)

    result = run_fixer([a, b])

    assert_equal 475680, b.timestamp_from  # first_word_start (476080) - 400ms buffer
    assert_equal 475679, a.timestamp_to    # trimmed to new b.from - 1
    assert_equal 1, result.fixed['ayah_overlap']
    assert_equal 0, result.after['ayah_overlap'].to_i
  end

  def test_clamps_ayah_overlap_to_just_before_next
    a = FakeSegment.new(verse_number: 1, from: 0, to: 14047, words: [[1, 0, 14047]])
    b = FakeSegment.new(verse_number: 2, from: 8947, to: 20000, words: [[1, 8947, 20000]])

    result = run_fixer([a, b])

    assert_equal 8946, a.timestamp_to
    assert_equal 1, result.fixed['ayah_overlap']
    assert_equal 0, result.after['ayah_overlap'].to_i
  end

  def test_skips_ayah_overlap_that_would_invert
    a = FakeSegment.new(verse_number: 1, from: 9000, to: 14000, words: [[1, 9000, 14000]])
    b = FakeSegment.new(verse_number: 2, from: 8000, to: 20000, words: [[1, 8000, 20000]])

    result = run_fixer([a, b])

    assert_equal 14000, a.timestamp_to
    assert_equal 1, result.skipped['ayah_overlap']
    refute a.changed?
  end

  def test_moves_ayah_start_to_first_word
    seg = FakeSegment.new(verse_number: 1, from: 1000, to: 5000, words: [[1, 500, 900], [2, 1000, 5000]], words_count: 2)

    result = run_fixer([seg])

    assert_equal 500, seg.timestamp_from
    assert_equal 1, result.fixed['ayah_timing']
    assert_equal 0, result.after['ayah_timing'].to_i
  end

  def test_fixes_ayah_start_and_trims_previous_when_first_word_slightly_before_previous_end
    # Mirrors the 26:33/26:34 case: next ayah's timestamp_from is too far ahead but its first
    # word starts just before the previous ayah ends. Fix: move this ayah's start to first word
    # and trim the previous ayah's end to first_word_start - 1.
    prev = FakeSegment.new(verse_number: 11, from: 190000, to: 194935, words: [[1, 190000, 194935]])
    seg = FakeSegment.new(verse_number: 12, from: 200000, to: 210000, words: [[1, 191000, 210000]], words_count: 1)

    result = run_fixer([prev, seg])

    assert_equal 191000, seg.timestamp_from
    assert_equal 190999, prev.timestamp_to
    assert_equal 1, result.fixed['ayah_timing']
    assert_equal 0, result.skipped['ayah_timing']
    # The danger start-side issue is resolved; a single advisory warning remains because the
    # previous ayah's last word tail (ends 194935) now extends past its trimmed boundary (190999).
    assert_equal 1, result.after['ayah_timing'].to_i
  end

  def test_skips_ayah_start_fix_when_trimming_previous_would_invert_it
    # first_word_start (191000) - 1 = 190999 < prev.timestamp_from (191001) → trimming would invert prev
    prev = FakeSegment.new(verse_number: 11, from: 191001, to: 194935, words: [[1, 191001, 194935]])
    seg = FakeSegment.new(verse_number: 12, from: 195135, to: 210000, words: [[1, 191000, 210000]], words_count: 1)

    result = run_fixer([prev, seg])

    assert_equal 195135, seg.timestamp_from
    refute seg.changed?
    assert_equal 1, result.skipped['ayah_timing']
    assert_equal 0, result.fixed['ayah_timing']
  end

  def test_moves_ayah_start_when_first_word_after_previous_ayah_end
    prev = FakeSegment.new(verse_number: 11, from: 100000, to: 120000, words: [[1, 100000, 120000]])
    seg = FakeSegment.new(verse_number: 12, from: 130000, to: 150000, words: [[1, 125000, 150000]], words_count: 1)

    result = run_fixer([prev, seg])

    assert_equal 125000, seg.timestamp_from
    assert_equal 1, result.fixed['ayah_timing']
  end

  def test_clamps_word_overlap_to_previous_word
    words = [[1, 0, 3000], [2, 2000, 4000]]
    seg = FakeSegment.new(verse_number: 1, from: 0, to: 4000, words: words, words_count: 2)

    result = run_fixer([seg])

    assert_equal 1999, seg.segments[0][2]
    assert_equal 1, result.fixed['word_overlap']
    assert_equal 0, result.after['word_overlap'].to_i
  end

  def test_skips_word_overlap_that_would_invert_previous_word
    words = [[1, 3000, 5000], [2, 2000, 6000]]
    seg = FakeSegment.new(verse_number: 1, from: 2000, to: 6000, words: words, words_count: 2)

    result = run_fixer([seg])

    assert_equal 5000, seg.segments[0][2]
    assert_equal 1, result.skipped['word_overlap']
  end

  def test_extends_previous_ayah_end_to_close_large_gap
    # Mirrors the 20:34/20:35 case: pure ayah_gap with no timing issue
    a = FakeSegment.new(verse_number: 1, from: 0, to: 510385, words: [[1, 0, 510385]])
    b = FakeSegment.new(verse_number: 2, from: 514480, to: 530000, words: [[1, 514480, 530000]])

    result = run_fixer([a, b])

    assert_equal 514080, a.timestamp_to  # 514480 - 400ms buffer
    assert_equal 514480, b.timestamp_from  # unchanged
    assert_equal 1, result.fixed['ayah_gap']
    assert_equal 0, result.after['ayah_gap'].to_i
  end

  def test_skips_gap_fix_when_resolved_by_ayah_timing_fix
    # If fix_ayah_first_word already closes the gap (by moving B's start forward), skip gap fix
    a = FakeSegment.new(verse_number: 1, from: 0, to: 510385, words: [[1, 0, 510385]])
    b = FakeSegment.new(verse_number: 2, from: 514480, to: 530000, words: [[1, 511000, 530000]], words_count: 1)

    result = run_fixer([a, b])

    # fix_ayah_first_word moves b's start to 511000, gap becomes 615ms — gap fix is skipped
    assert_equal 511000, b.timestamp_from
    assert_equal 0, result.fixed['ayah_gap'].to_i
    assert_equal 0, result.after['ayah_gap'].to_i
  end

  def test_leaves_small_gaps_untouched
    a = FakeSegment.new(verse_number: 1, from: 0, to: 5000, words: [[1, 0, 5000]])
    b = FakeSegment.new(verse_number: 2, from: 6500, to: 12000, words: [[1, 6500, 12000]])

    result = run_fixer([a, b])

    refute a.changed?
    refute b.changed?
    assert_equal 0, result.after['ayah_gap'].to_i
  end
end
