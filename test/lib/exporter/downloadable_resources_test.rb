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
    def word_segments?
      word_segments
    end
  end

  class FakeDownloadableResource
    attr_reader :tag_names

    def initialize(tag_names)
      @tag_names = tag_names
    end

    def new_record?
      false
    end

    def save(*)
      true
    end

    def remove_tags(names)
      @tag_names -= names
    end

    def tags=(val)
      @tag_names = (@tag_names + val.split(',').map(&:strip).reject(&:empty?)).uniq
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

  def test_set_tags_drops_segment_tags_that_no_longer_apply
    resource = FakeDownloadableResource.new(['Recitation', 'With segments', 'Word segments'])

    @exporter.send(:set_tags, resource, ['Recitation', 'Ayah segments'], remove: Exporter::DownloadableResources::SEGMENT_TAGS)

    assert_equal ['Recitation', 'Ayah segments'], resource.tag_names
  end

  def test_set_tags_keeps_existing_tags_when_nothing_to_remove
    resource = FakeDownloadableResource.new(['Recitation', 'Custom'])

    @exporter.send(:set_tags, resource, ['Recitation', 'Partial'])

    assert_equal ['Recitation', 'Custom', 'Partial'], resource.tag_names
  end
end
