require_relative '../../test_helper'
require_relative '../../../app/services/resources/search_query'

class SearchQueryTest < Minitest::Test
  include ResourceSearchTestSupport

  def setup
    install_quran_fixture
  end

  def test_text_and_tag_filters_are_applied_with_and_logic
    english = FakeTagRecord.new(name: 'English', slug: 'english')
    with_footnotes = FakeTagRecord.new(name: 'Footnotes', slug: 'footnotes')
    arabic = FakeTagRecord.new(name: 'Arabic', slug: 'arabic')

    resources = [
      build_resource(
        id: 1,
        name: 'Clear English Translation',
        resource_type: 'translation',
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        tags: [english, with_footnotes],
        info: 'English translation with notes'
      ),
      build_resource(
        id: 2,
        name: 'Arabic Translation Notes',
        resource_type: 'translation',
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        tags: [arabic, with_footnotes],
        info: 'Arabic commentary'
      )
    ]

    result = Resources::SearchQuery.new(
      scope: resources,
      query: 'translation',
      selected_tags: ['Footnotes', 'English'],
      global: false
    ).call

    assert_equal ['Clear English Translation'], result.results.map(&:name)
    assert_equal ['English', 'Footnotes'], result.available_tags.map(&:name)
    assert_equal ['Footnotes', 'English'], result.selected_tags
  end

  def test_resource_type_filters_are_applied_after_type_facets_are_built
    english = FakeTagRecord.new(name: 'English', slug: 'english')

    resources = [
      build_resource(
        id: 1,
        name: 'Clear English Translation',
        resource_type: 'translation',
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        tags: [english],
        info: 'Simple translation'
      ),
      build_resource(
        id: 2,
        name: 'Fatihah Tafsir',
        resource_type: 'tafsir',
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        tags: [english],
        info: 'Detailed tafsir'
      )
    ]

    result = Resources::SearchQuery.new(
      scope: resources,
      query: 'english',
      selected_tags: [],
      selected_resource_types: ['translation'],
      global: true
    ).call

    assert_equal ['Clear English Translation'], result.results.map(&:name)
    assert_equal ['Tafsir', 'Translation'], result.available_resource_types.map(&:name).sort
    assert_equal ['translation'], result.selected_resource_types
    assert_equal ['English'], result.available_tags.map(&:name)
  end

  def test_surah_name_only_query_remains_plain_text_search
    english = FakeTagRecord.new(name: 'English', slug: 'english')

    resources = [
      build_resource(
        id: 1,
        name: 'Fatihah Tafsir',
        resource_type: 'tafsir',
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        tags: [english],
        info: 'Detailed tafsir for the opening surah'
      )
    ]

    result = Resources::SearchQuery.new(
      scope: resources,
      query: 'fatihah',
      selected_tags: [],
      global: true
    ).call

    refute result.quran_reference?
    assert_equal ['Fatihah Tafsir'], result.results.map(&:name)
  end
end
