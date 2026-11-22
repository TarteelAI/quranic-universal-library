require 'test_helper'

# ApplicationPresenter includes Pagy::Backend; the catalog doesn't use it.
module Pagy
  module Backend; end
end unless defined?(Pagy::Backend)

unless Object.const_defined?(:ResourcePermission)
  class ::ResourcePermission
    class << self
      attr_accessor :rejected_ids

      def share_permission_is_rejected
        rejected = rejected_ids || []
        Object.new.tap { |scope| scope.define_singleton_method(:pluck) { |*| rejected } }
      end
    end
  end
end

unless Object.const_defined?(:Language)
  class ::Language
    class << self
      attr_accessor :records

      def where(id:)
        (records || []).select { |language| id.include?(language.id) }.tap do |found|
          found.define_singleton_method(:order) { |*| self }
        end
      end
    end
  end
end

require_relative '../../../app/presenters/application_presenter'
require_relative '../../../app/presenters/v1/api_presenter'
require_relative '../../../app/presenters/v1/resources_presenter'

class ResourcesPresenterTest < Minitest::Test
  Resource = Struct.new(:id, :language_id, keyword_init: true)
  LanguageRecord = Struct.new(:id, :name, :iso_code, :native_name, :direction, keyword_init: true)

  # Just enough of an ActiveRecord relation for the catalog queries.
  class FakeRelation
    attr_reader :records

    def initialize(records)
      @records = records
    end

    def translations = self
    def tafsirs = self
    def approved = self
    def one_verse = self
    def order(*) = self
    def group(*) = self

    def where(*args)
      raise ArgumentError, 'only where.not is faked' unless args.empty?

      relation = self
      Object.new.tap do |chain|
        chain.define_singleton_method(:not) do |id:|
          FakeRelation.new(relation.records.reject { |record| id.include?(record.id) })
        end
      end
    end

    def count
      records.group_by(&:language_id).transform_values(&:size)
    end
  end

  def setup
    translations = FakeRelation.new([
      Resource.new(id: 131, language_id: 38),
      Resource.new(id: 20, language_id: 38),
      Resource.new(id: 79, language_id: 174)
    ])
    ::ResourceContent.define_singleton_method(:translations) { translations }
    ::ResourceContent.define_singleton_method(:tafsirs) { FakeRelation.new([]) }
    ::ResourcePermission.rejected_ids = [131]
    ::Language.records = [
      LanguageRecord.new(id: 38, name: 'english', iso_code: 'en'),
      LanguageRecord.new(id: 174, name: 'urdu', iso_code: 'ur')
    ]

    @presenter = V1::ResourcesPresenter.allocate
    @presenter.instance_variable_set(:@params, {})
    @presenter.instance_variable_set(:@translated_names_cache, {})
    @presenter.define_singleton_method(:process_results) { |records, **| records }
  end

  def teardown
    ::ResourceContent.singleton_class.send(:remove_method, :translations)
    ::ResourceContent.singleton_class.send(:remove_method, :tafsirs)
    ::ResourcePermission.rejected_ids = nil
    ::Language.records = nil
  end

  # /translations/:id/by_range and /translations/for_ayah refuse a translation
  # whose share permission was rejected, so the catalog must not offer it.
  def test_translations_skip_resources_whose_share_permission_was_rejected
    assert_equal [20, 79], @presenter.translations.records.map(&:id)
  end

  def test_language_counts_skip_resources_whose_share_permission_was_rejected
    counts = @presenter.languages.to_h { |language| [language[:iso_code], language[:translations_count]] }

    assert_equal({ 'en' => 1, 'ur' => 1 }, counts)
  end
end
