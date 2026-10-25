require 'minitest/autorun'
require 'active_support/all'
require_relative '../../app/models/concerns/exported_asset_versioning'

class ExportedAssetVersioningTest < Minitest::Test
  class FakeResourceContent
    include ExportedAssetVersioning

    def initialize(meta = {})
      @meta = meta
    end

    def meta_value(key)
      @meta[key.to_s]
    end

    def set_meta_value(key, value)
      @meta[key.to_s] = value
    end
  end

  SEGMENTS = '{"1":[{"ayah":1,"start":0,"end":5000}]}'

  def test_first_export_keeps_the_version_clients_already_have
    resource = FakeResourceContent.new('exported-version' => 1_700_000_000)

    refute resource.sync_exported_asset_version('segments', SEGMENTS)
    assert_equal 1_700_000_000, resource.exported_asset_version('segments')
  end

  def test_re_exporting_unchanged_data_does_not_move_the_version
    resource = FakeResourceContent.new('exported-version' => 1_700_000_000)
    resource.sync_exported_asset_version('segments', SEGMENTS)

    refute resource.sync_exported_asset_version('segments', SEGMENTS.dup)
    assert_equal 1_700_000_000, resource.exported_asset_version('segments')
  end

  def test_changed_data_bumps_the_version
    resource = FakeResourceContent.new('exported-version' => 1_700_000_000)
    resource.sync_exported_asset_version('segments', SEGMENTS)

    assert resource.sync_exported_asset_version('segments', SEGMENTS.sub('5000', '5200'))
    assert_equal 1_700_000_001, resource.exported_asset_version('segments')
  end

  def test_segments_and_audio_version_independently
    resource = FakeResourceContent.new('exported-version' => 1_700_000_000)
    resource.sync_exported_asset_version('segments', SEGMENTS)
    resource.sync_exported_asset_version('audio', '[{"surah":1,"version":7}]')

    assert resource.sync_exported_asset_version('segments', SEGMENTS.sub('5000', '5200'))

    assert_equal 1_700_000_001, resource.exported_asset_version('segments')
    assert_equal 1_700_000_000, resource.exported_asset_version('audio')
  end

  def test_size_is_recorded_for_the_manifest
    resource = FakeResourceContent.new
    resource.sync_exported_asset_version('segments', SEGMENTS)

    assert_equal SEGMENTS.bytesize, resource.exported_asset_size('segments')
  end

  def test_a_resource_with_no_legacy_version_gets_a_usable_one
    resource = FakeResourceContent.new

    assert resource.sync_exported_asset_version('audio', '[]')
    assert_operator resource.exported_asset_version('audio'), :>, 1_700_000_000
  end
end
