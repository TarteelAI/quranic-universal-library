require_relative '../../test_helper'
require_relative '../../../app/services/resources/quran_reference_parser'
require_relative '../../../app/services/resources/search_query'

class SearchQueryTest < Minitest::Test
  include ResourceSearchTestSupport

  def setup
    install_quran_fixture
  end

  def test_quran_reference_search_splits_primary_and_related_results
    segmented = FakeTagRecord.new(name: 'Segmented', slug: 'segmented')
    arabic = FakeTagRecord.new(name: 'Arabic', slug: 'arabic')
    typography = FakeTagRecord.new(name: 'Typography', slug: 'typography')

    resources = [
      build_resource(
        id: 1,
        name: 'Ayah Recitation',
        resource_type: 'recitation',
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        tags: [segmented]
      ),
      build_resource(
        id: 2,
        name: 'Quran Script',
        resource_type: 'quran-script',
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        tags: [arabic]
      ),
      build_resource(
        id: 3,
        name: 'Quran Font Pack',
        resource_type: 'font',
        cardinality_type: ResourceContent::CardinalityType::Quran,
        tags: [typography]
      )
    ]

    result = Resources::SearchQuery.new(
      scope: resources,
      query: '2:255',
      selected_tags: [],
      global: true
    ).call

    assert result.quran_reference?
    assert_equal '2:255', result.normalized_ayah
    assert_equal ['Ayah Recitation', 'Quran Script'], result.primary_results.map(&:name)
    assert_equal ['Quran Font Pack'], result.related_results.map(&:name)
    assert_equal ['Arabic', 'Segmented', 'Typography'], result.available_tags.map(&:name)
    assert_equal ['Font', 'Quran Script', 'Recitation'], result.available_resource_types.map(&:name)
  end

  def test_surah_alias_quran_reference_search_matches_same_ayah_context
    segmented = FakeTagRecord.new(name: 'Segmented', slug: 'segmented')
    arabic = FakeTagRecord.new(name: 'Arabic', slug: 'arabic')

    resources = [
      build_resource(
        id: 1,
        name: 'Fatihah Recitation',
        resource_type: 'recitation',
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        tags: [segmented]
      ),
      build_resource(
        id: 2,
        name: 'Fatihah Quran Script',
        resource_type: 'quran-script',
        cardinality_type: ResourceContent::CardinalityType::OneVerse,
        tags: [arabic]
      )
    ]

    result = Resources::SearchQuery.new(
      scope: resources,
      query: 'fateh 1',
      selected_tags: [],
      global: true
    ).call

    assert result.quran_reference?
    assert_equal '1:1', result.normalized_ayah
    assert_equal ['Fatihah Quran Script', 'Fatihah Recitation'], result.results.map(&:name).sort
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
