require 'test_helper'

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  test "should get morphology categories" do
    get "/api/v1/search/morphology_categories"
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert json_response['categories'].present?
    assert json_response['categories'].any? { |c| c['value'] == 'noun' }
    assert json_response['categories'].any? { |c| c['value'] == 'verb' }
  end

  test "should get arabic scripts" do
    get "/api/v1/search/arabic_scripts"
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert json_response['scripts'].present?
    assert json_response['scripts'].any? { |s| s['value'] == 'qpc_hafs' }
    assert json_response['scripts'].any? { |s| s['value'] == 'uthmani' }
  end

  test "should return empty suggestions for blank query" do
    get "/api/v1/search/suggestions?q="
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal [], json_response['suggestions']['roots']
    assert_equal [], json_response['suggestions']['lemmas']
    assert_equal [], json_response['suggestions']['stems']
  end

  test "should require query parameter for advanced search" do
    post "/api/v1/search/advanced", 
         params: { search: { type: 'text' } },
         as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert json_response['error'].present?
  end

  test "should validate search type parameter" do
    post "/api/v1/search/advanced", 
         params: { search: { query: 'test', type: 'invalid_type' } },
         as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_match /Invalid search type/, json_response['error']
  end

  test "should validate script parameter" do
    post "/api/v1/search/advanced", 
         params: { search: { query: 'test', script: 'invalid_script' } },
         as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_match /Invalid script type/, json_response['error']
  end

  test "should perform advanced search with valid parameters" do
    # Mock the search service to avoid database dependencies
    mock_result = {
      type: 'text',
      query: 'الله',
      verses: [],
      total_count: 0,
      filters: {}
    }
    
    Search::AdvancedSearchService.any_instance.stubs(:search).returns(mock_result)
    
    post "/api/v1/search/advanced", 
         params: { 
           search: { 
             query: 'الله', 
             type: 'text',
             include_translations: true 
           } 
         },
         as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert json_response['search'].present?
    assert json_response['data'].present?
    assert_equal 'الله', json_response['search']['query']
    assert_equal 'text', json_response['search']['type']
  end
end