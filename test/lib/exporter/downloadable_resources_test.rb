require 'minitest/autorun'
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
end
