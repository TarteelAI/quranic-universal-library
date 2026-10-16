require 'minitest/autorun'

module ActiveRecord
  class Migration
    def self.[](_version)
      self
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

  Resource = Struct.new(:id, :resource_type, keyword_init: true) do
    def update!(resource_type:)
      self.resource_type = resource_type
    end
  end
  Tag = Struct.new(:id, :name, keyword_init: true)

  class ResourceModel
    class << self
      attr_accessor :record

      def find_by(id:)
        record if record&.id == id
      end
    end
  end

  class TagModel
    class << self
      attr_accessor :records

      def find_by!(name:)
        records.find { |tag| tag.name == name } || raise("Missing tag: #{name}")
      end
    end
  end

  class TaggingModel
    class << self
      attr_accessor :records

      def where(attributes)
        Relation.new(records, attributes)
      end

      def find_or_create_by!(attributes)
        records << attributes unless records.include?(attributes)
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

  def setup
    ResourceModel.record = Resource.new(id: RESOURCE_ID, resource_type: TRANSLATION_TYPE)
    TagModel.records = [
      Tag.new(id: TRANSLATION_TAG_ID, name: 'Translation'),
      Tag.new(id: TRANSLITERATION_TAG_ID, name: 'Transliteration')
    ]
    TaggingModel.records = [
      { downloadable_resource_id: RESOURCE_ID, downloadable_resource_tag_id: TRANSLATION_TAG_ID }
    ]

    @migration = ReclassifyEnglishRtfTransliteration.new
    @migration.resource_model = ResourceModel
    @migration.tag_model = TagModel
    @migration.tagging_model = TaggingModel
  end

  def test_up_moves_resource_from_translation_to_transliteration
    @migration.up

    assert_equal TRANSLITERATION_TYPE, ResourceModel.record.resource_type
    assert_equal [
      { downloadable_resource_id: RESOURCE_ID, downloadable_resource_tag_id: TRANSLITERATION_TAG_ID }
    ], TaggingModel.records
  end

  def test_down_restores_translation_classification
    @migration.up
    @migration.down

    assert_equal TRANSLATION_TYPE, ResourceModel.record.resource_type
    assert_equal [
      { downloadable_resource_id: RESOURCE_ID, downloadable_resource_tag_id: TRANSLATION_TAG_ID }
    ], TaggingModel.records
  end
end
