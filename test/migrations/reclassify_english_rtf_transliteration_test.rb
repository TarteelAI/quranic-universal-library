require 'minitest/autorun'

module ActiveRecord
  class Migration
    def self.[](_version)
      self
    end
  end
end

# The downloadable-resource models are redefined here so the migration can be
# exercised without booting Rails, the same way test/test_helper.rb stands in
# for Chapter, Verse and ResourceContent.
class FakeResourceRecord
  attr_reader :id
  attr_accessor :resource_type

  def initialize(id:, resource_type:)
    @id = id
    @resource_type = resource_type
  end

  def update!(resource_type:)
    @resource_type = resource_type
  end
end

FakeTagRecord = Struct.new(:id, :name, keyword_init: true)

class ::DownloadableResource
  class << self
    attr_accessor :record

    def find_by(id:)
      record if record&.id == id
    end
  end
end

class ::DownloadableResourceTag
  class << self
    attr_accessor :records

    def find_by!(name:)
      records.find { |tag| tag.name == name } || raise("Missing tag: #{name}")
    end
  end
end

class ::DownloadableResourceTagging
  class << self
    attr_accessor :records

    def where(attributes)
      Relation.new(records, attributes)
    end

    def find_or_create_by!(attributes)
      records << attributes unless records.include?(attributes)
      attributes
    end
  end

  class Relation
    def initialize(records, attributes)
      @records = records
      @attributes = attributes
    end

    def delete_all
      @records.delete_if { |record| @attributes.all? { |key, value| record[key] == value } }
    end
  end
end

require_relative '../../db/migrate/20261016000000_reclassify_english_rtf_transliteration'

class ReclassifyEnglishRtfTransliterationTest < Minitest::Test
  RESOURCE_ID = 470
  TRANSLATION_TYPE = 'translation'
  TRANSLITERATION_TYPE = 'transliteration'
  TRANSLATION_TAG_ID = 1
  TRANSLITERATION_TAG_ID = 2

  def setup
    DownloadableResource.record = FakeResourceRecord.new(id: RESOURCE_ID, resource_type: TRANSLATION_TYPE)
    DownloadableResourceTag.records = [
      FakeTagRecord.new(id: TRANSLATION_TAG_ID, name: 'Translation'),
      FakeTagRecord.new(id: TRANSLITERATION_TAG_ID, name: 'Transliteration')
    ]
    DownloadableResourceTagging.records = [
      { downloadable_resource_id: RESOURCE_ID, downloadable_resource_tag_id: TRANSLATION_TAG_ID }
    ]

    @migration = ReclassifyEnglishRtfTransliteration.new
  end

  def test_up_moves_resource_from_translation_to_transliteration
    @migration.up

    assert_equal TRANSLITERATION_TYPE, DownloadableResource.record.resource_type
    assert_equal [
      { downloadable_resource_id: RESOURCE_ID, downloadable_resource_tag_id: TRANSLITERATION_TAG_ID }
    ], DownloadableResourceTagging.records
  end

  def test_down_restores_translation_classification
    @migration.up
    @migration.down

    assert_equal TRANSLATION_TYPE, DownloadableResource.record.resource_type
    assert_equal [
      { downloadable_resource_id: RESOURCE_ID, downloadable_resource_tag_id: TRANSLATION_TAG_ID }
    ], DownloadableResourceTagging.records
  end

  def test_up_is_idempotent
    @migration.up
    @migration.up

    assert_equal [
      { downloadable_resource_id: RESOURCE_ID, downloadable_resource_tag_id: TRANSLITERATION_TAG_ID }
    ], DownloadableResourceTagging.records
  end

  def test_up_does_nothing_when_the_resource_is_absent
    DownloadableResource.record = nil

    @migration.up

    assert_equal [
      { downloadable_resource_id: RESOURCE_ID, downloadable_resource_tag_id: TRANSLATION_TAG_ID }
    ], DownloadableResourceTagging.records
  end
end
