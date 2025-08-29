require 'test_helper'

class Search::AdvancedSearchServiceTest < ActiveSupport::TestCase
  def setup
    @search_service = Search::AdvancedSearchService.new('الله')
  end

  test "should initialize with query and options" do
    service = Search::AdvancedSearchService.new('test query', type: 'text')
    assert_equal 'test query', service.query
    assert_equal :text, service.send(:search_type)
  end

  test "should return empty result for blank query" do
    service = Search::AdvancedSearchService.new('')
    result = service.search
    
    assert_equal 0, result[:total_count]
    assert_equal [], result[:verses]
    assert_equal 'Empty query', result[:message]
  end

  test "should handle search errors gracefully" do
    # Mock an error in the search process
    service = Search::AdvancedSearchService.new('test')
    service.stub(:text_search, -> { raise StandardError, 'Test error' }) do
      result = service.search
      assert result[:error].present?
      assert_equal 0, result[:total_count]
    end
  end

  test "should extract filters correctly" do
    service = Search::AdvancedSearchService.new('test', {
      chapter_id: '1',
      script: 'qpc_hafs',
      include_translations: 'true',
      include_tafsirs: 'false'
    })
    
    filters = service.send(:extract_filters)
    assert_equal '1', filters[:chapter_id]
    assert_equal :qpc_hafs, filters[:script]
    assert_equal true, filters[:include_translations]
    assert_equal false, filters[:include_tafsirs]
  end

  test "should parse morphology categories" do
    service = Search::AdvancedSearchService.new('noun')
    assert_equal 'noun', service.send(:parse_morphology_category)
    
    service = Search::AdvancedSearchService.new('اسم')
    assert_equal 'noun', service.send(:parse_morphology_category)
    
    service = Search::AdvancedSearchService.new('verb')
    assert_equal 'verb', service.send(:parse_morphology_category)
  end

  test "should expand semantic queries" do
    service = Search::AdvancedSearchService.new('mercy')
    expanded = service.send(:expand_semantic_query, 'mercy')
    
    assert expanded.include?('mercy')
    assert expanded.include?('forgiveness')
    assert expanded.include?('compassion')
  end

  test "should identify morphology queries" do
    service = Search::AdvancedSearchService.new('noun')
    assert service.send(:might_be_morphology_query?)
    
    service = Search::AdvancedSearchService.new('اسم')
    assert service.send(:might_be_morphology_query?)
    
    service = Search::AdvancedSearchService.new('random text')
    refute service.send(:might_be_morphology_query?)
  end

  test "should format results correctly" do
    service = Search::AdvancedSearchService.new('test')
    result = service.send(:format_results, { verses: [], total_count: 0 })
    
    assert_equal :combined, result[:type]
    assert_equal 'test', result[:query]
    assert result[:filters].present?
    assert_equal 0, result[:total_count]
  end
end