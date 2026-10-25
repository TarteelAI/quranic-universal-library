require 'minitest/autorun'
require 'active_support/all'
require_relative '../../app/models/concerns/audio_content_versioning'

class AudioContentVersioningTest < Minitest::Test
  class FakeAudioFile
    include AudioContentVersioning

    attr_accessor :content_hash, :content_etag, :content_version, :content_updated_at, :content_version_source, :updated_at
    attr_reader :saves

    def initialize(updated_at: Time.at(1_700_000_000), content_version: nil, content_hash: nil)
      @updated_at = updated_at
      @content_version = content_version
      @content_hash = content_hash
      @saves = 0
    end

    def save(*)
      @saves += 1
      true
    end
  end

  PROBE = { size_bytes: 1_234_567, duration_ms: 90_000, bitrate: 128_000, sample_rate: 44_100 }.freeze

  def test_published_version_falls_back_to_updated_at
    file = FakeAudioFile.new(updated_at: Time.at(1_700_000_000))
    assert_equal 1_700_000_000, file.published_version
  end

  def test_first_fingerprint_keeps_the_version_clients_already_have
    file = FakeAudioFile.new(updated_at: Time.at(1_700_000_000))

    # Nothing to compare against yet, so the published number must not move.
    refute file.sync_content_version(PROBE)
    assert_equal 1_700_000_000, file.content_version
    refute_nil file.content_hash
  end

  def test_unchanged_audio_does_not_move_the_version
    file = FakeAudioFile.new
    file.sync_content_version(PROBE)
    version = file.content_version

    refute file.sync_content_version(PROBE.dup)
    assert_equal version, file.content_version
  end

  def test_changed_audio_bumps_the_version
    file = FakeAudioFile.new
    file.sync_content_version(PROBE)
    version = file.content_version

    assert file.sync_content_version(PROBE.merge(size_bytes: 2_000_000))
    assert_equal version + 1, file.content_version
    assert_equal AudioContentVersioning::FINGERPRINT_SOURCE, file.content_version_source
  end

  def test_etag_alone_is_enough_to_detect_a_change
    file = FakeAudioFile.new
    file.sync_content_version(PROBE.merge(etag: 'abc'))
    version = file.content_version

    assert file.sync_content_version(PROBE.merge(etag: 'def'))
    assert_equal version + 1, file.content_version
  end

  def test_a_missing_etag_is_not_treated_as_a_change
    file = FakeAudioFile.new
    file.sync_content_version(PROBE.merge(etag: 'abc'))
    version = file.content_version

    # HEAD timed out this time round - the probed values still match.
    refute file.sync_content_version(PROBE.dup)
    assert_equal version, file.content_version
    assert_equal 'abc', file.content_etag
  end

  def test_matching_etag_outranks_probe_noise
    file = FakeAudioFile.new
    file.sync_content_version(PROBE.merge(etag: 'abc'))
    version = file.content_version

    # Same object, but ffprobe reported the bitrate differently this time.
    refute file.sync_content_version(PROBE.merge(etag: 'abc', bitrate: 127_998))
    assert_equal version, file.content_version
  end

  def test_empty_probe_is_ignored
    file = FakeAudioFile.new
    refute file.sync_content_version({})
    assert_nil file.content_hash
  end

  def test_admin_can_override_the_version
    file = FakeAudioFile.new
    file.sync_content_version(PROBE)

    assert file.override_content_version!(42)
    assert_equal 42, file.content_version
    assert file.content_version_overridden?
    assert_equal 1, file.saves
  end

  def test_override_rejects_non_positive_versions
    file = FakeAudioFile.new(content_version: 7)

    refute file.override_content_version!(0)
    refute file.override_content_version!('nope')
    assert_equal 7, file.content_version
  end

  def test_bump_moves_one_past_the_published_version
    file = FakeAudioFile.new(updated_at: Time.at(1_700_000_000))

    file.bump_content_version!
    assert_equal 1_700_000_001, file.content_version
    assert file.content_version_overridden?
  end

  def test_fingerprint_change_still_wins_after_a_manual_override
    file = FakeAudioFile.new
    file.sync_content_version(PROBE)
    file.override_content_version!(500)

    assert file.sync_content_version(PROBE.merge(duration_ms: 95_000))
    assert_equal 501, file.content_version
    assert_equal AudioContentVersioning::FINGERPRINT_SOURCE, file.content_version_source
  end
end
