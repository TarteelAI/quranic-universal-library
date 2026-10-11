require 'minitest/autorun'
require 'rake'

class SplitRecitationSegmentTagsTest < Minitest::Test
  FakeTag = Struct.new(:id, :name, keyword_init: true)
  FakeRecitation = Struct.new(:word_segments, keyword_init: true) do
    def has_word_segments?
      word_segments
    end
  end

  class FakeResource
    attr_reader :resource_content_id, :tag_names

    def initialize(resource_content_id:, chapter:, tag_names:)
      @resource_content_id = resource_content_id
      @chapter = chapter
      @tag_names = tag_names
    end

    def chapter?
      @chapter
    end

    def tags=(val)
      @tag_names = (@tag_names + val.split(',')).uniq
    end
  end

  class FakeTagging
    attr_reader :downloadable_resource

    def initialize(store, downloadable_resource)
      @store = store
      @downloadable_resource = downloadable_resource
    end

    def destroy
      @store.delete(self)
      downloadable_resource.tag_names.delete('With segments')
    end
  end

  class FakeTaggingScope
    def initialize(taggings)
      @taggings = taggings
    end

    def includes(*)
      self
    end

    def find_each(&block)
      @taggings.dup.each(&block)
    end
  end

  class ::DownloadableResourceTag
    class << self
      attr_accessor :records

      def where(_sql, name)
        records.select { |tag| tag.name.downcase == name }
      end
    end
  end

  class ::DownloadableResourceTagging
    class << self
      attr_accessor :records

      def where(downloadable_resource_tag_id:)
        FakeTaggingScope.new(records)
      end
    end
  end

  module ::Audio
    class Recitation
      class << self
        attr_accessor :records

        def find_by(resource_content_id:)
          records[resource_content_id]
        end
      end
    end
  end

  def setup
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load File.expand_path('../../../lib/tasks/one_time.rake', __dir__)

    @ayah_only = FakeResource.new(resource_content_id: 1, chapter: true, tag_names: ['Recitation', 'With segments'])
    @with_words = FakeResource.new(resource_content_id: 2, chapter: true, tag_names: ['Recitation', 'With segments'])
    @gapped = FakeResource.new(resource_content_id: 3, chapter: false, tag_names: ['Recitation', 'With segments'])

    DownloadableResourceTag.records = [FakeTag.new(id: 10, name: 'With segments')]
    DownloadableResourceTagging.records = []
    [@ayah_only, @with_words, @gapped].each do |resource|
      DownloadableResourceTagging.records << FakeTagging.new(DownloadableResourceTagging.records, resource)
    end
    Audio::Recitation.records = {
      1 => FakeRecitation.new(word_segments: false),
      2 => FakeRecitation.new(word_segments: true)
    }
  end

  def run_task
    Rake::Task['one_time:split_recitation_segment_tags'].reenable
    Rake::Task['one_time:split_recitation_segment_tags'].invoke
  end

  def test_replaces_with_segments_tag_based_on_available_timing
    run_task

    assert_equal ['Recitation', 'Ayah segments'], @ayah_only.tag_names
    assert_equal ['Recitation', 'Ayah segments', 'Word segments'], @with_words.tag_names
    assert_equal ['Recitation', 'Word segments'], @gapped.tag_names
    assert_empty DownloadableResourceTagging.records
  end

  def test_running_twice_does_not_change_tags_again
    run_task
    run_task

    assert_equal ['Recitation', 'Ayah segments', 'Word segments'], @with_words.tag_names
  end

  def test_does_nothing_when_old_tag_does_not_exist
    DownloadableResourceTag.records = []

    run_task

    assert_equal ['Recitation', 'With segments'], @ayah_only.tag_names
  end
end
