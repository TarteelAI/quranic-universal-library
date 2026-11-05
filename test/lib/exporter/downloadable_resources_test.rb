require 'minitest/autorun'
require 'tmpdir'
require 'active_support/core_ext/object/blank'
require_relative '../../../lib/exporter/downloadable_resources'

class DownloadableResourcesTest < Minitest::Test
  FakeContent = Struct.new(:has_segments, keyword_init: true) do
    def has_segments?
      has_segments
    end
  end

  FakeRecitation = Struct.new(:word_segments, keyword_init: true) do
    def has_word_segments?
      word_segments
    end
  end

  def setup
    @exporter = Exporter::DownloadableResources.new
  end

  def segment_tags(has_segments:, word_segments:)
    @exporter.send(
      :surah_recitation_segment_tags,
      FakeContent.new(has_segments: has_segments),
      FakeRecitation.new(word_segments: word_segments)
    )
  end

  def test_surah_recitation_with_only_ayah_timing_gets_ayah_segments_tag
    assert_equal ['Ayah segments'], segment_tags(has_segments: true, word_segments: false)
  end

  def test_surah_recitation_with_word_timing_gets_both_segment_tags
    assert_equal ['Ayah segments', 'Word segments'], segment_tags(has_segments: true, word_segments: true)
  end

  def test_surah_recitation_without_segments_gets_no_segment_tags
    assert_equal [], segment_tags(has_segments: false, word_segments: true)
  end

  def test_export_all_starts_when_export_directory_is_missing
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        export_started = false
        @exporter.define_singleton_method(:export_surah_info) do
          export_started = true
          throw :export_started
        end

        catch(:export_started) { @exporter.export_all }

        assert export_started
      end
    end
  end

  def test_export_all_removes_stale_export_directory
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir_p('tmp/export')
        File.write('tmp/export/stale.db', 'stale')
        export_directory_removed = false
        @exporter.define_singleton_method(:export_surah_info) do
          export_directory_removed = !File.exist?('tmp/export')
          throw :export_started
        end

        catch(:export_started) { @exporter.export_all }

        assert export_directory_removed
      end
    end
  end
end
