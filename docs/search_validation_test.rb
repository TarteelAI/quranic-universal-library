# frozen_string_literal: true

# Basic test for Elasticsearch search functionality
# This can be run manually in Rails console or as a basic validation script

class SearchValidationTest
  def self.run_all_tests
    puts "🔍 Running Elasticsearch Search Validation Tests"
    puts "=" * 50
    
    # Test 1: Check if Elasticsearch is available
    test_elasticsearch_connection
    
    # Test 2: Test basic search functionality  
    test_basic_search
    
    # Test 3: Test API controller functionality
    test_api_controller
    
    # Test 4: Test morphology search
    test_morphology_search
    
    # Test 5: Test admin search integration
    test_admin_search_integration
    
    puts "\n✅ All tests completed!"
  end

  private

  def self.test_elasticsearch_connection
    puts "\n1. Testing Elasticsearch Connection..."
    
    begin
      if defined?(Searchkick)
        client = Searchkick.client
        health = client.cluster.health
        puts "   ✅ Elasticsearch connected: #{health['status']}"
        puts "   ℹ️  Cluster: #{health['cluster_name']}"
        puts "   ℹ️  Nodes: #{health['number_of_nodes']}"
      else
        puts "   ⚠️  Searchkick not loaded, will use fallback search"
      end
    rescue => e
      puts "   ❌ Elasticsearch connection failed: #{e.message}"
      puts "   ℹ️  Tests will use fallback database search"
    end
  end

  def self.test_basic_search
    puts "\n2. Testing Basic Search Functionality..."
    
    begin
      # Test Verse search
      if Verse.respond_to?(:elasticsearch_search)
        puts "   Testing Verse.elasticsearch_search..."
        verses = Verse.limit(5) # Get some verses for testing
        if verses.any?
          # Test with actual verse text
          test_query = verses.first.text_uthmani&.split(' ')&.first || "الله"
          results = Verse.elasticsearch_search(test_query, per_page: 3)
          puts "   ✅ Verse search working: found #{results.count} results for '#{test_query}'"
        else
          puts "   ⚠️  No verses found in database for testing"
        end
      else
        puts "   ❌ Verse.elasticsearch_search method not found"
      end

      # Test QuranSearch utility
      puts "   Testing Utils::QuranSearch..."
      search_util = Utils::QuranSearch.new
      result = search_util.search("الله")
      
      if result.is_a?(Hash)
        verse_count = result['verses']&.length || 0
        puts "   ✅ QuranSearch utility working: found #{verse_count} verses"
        
        if result['error']
          puts "   ⚠️  Search returned error: #{result['error']}"
        end
      else
        puts "   ❌ QuranSearch returned unexpected format"
      end
      
    rescue => e
      puts "   ❌ Basic search test failed: #{e.message}"
    end
  end

  def self.test_api_controller
    puts "\n3. Testing API Controller..."
    
    begin
      # Create a test API client if none exists
      test_client = ApiClient.find_by(name: 'Test Client') || 
                   ApiClient.create!(
                     name: 'Test Client',
                     active: true,
                     request_quota: 1000
                   )
      
      puts "   ✅ Test API client ready: #{test_client.name}"
      puts "   ℹ️  API Key: #{test_client.api_key}"
      
      # Test controller class exists
      if defined?(Api::V1::SearchController)
        puts "   ✅ API Search controller loaded"
        
        # Test controller methods
        controller = Api::V1::SearchController.new
        required_methods = %w[general_search morphology_search semantic_search script_search autocomplete]
        
        missing_methods = required_methods.reject { |method| controller.respond_to?(method, true) }
        
        if missing_methods.empty?
          puts "   ✅ All required controller methods present"
        else
          puts "   ❌ Missing controller methods: #{missing_methods.join(', ')}"
        end
      else
        puts "   ❌ API Search controller not found"
      end
      
    rescue => e
      puts "   ❌ API controller test failed: #{e.message}"
    end
  end

  def self.test_morphology_search
    puts "\n4. Testing Morphology Search..."
    
    begin
      if Word.respond_to?(:morphology_search)
        # Test morphology search with common parameters
        results = Word.morphology_search(part_of_speech: 'noun')
        puts "   ✅ Morphology search working: found #{results.count} nouns"
        
        # Test with root search if morphology data exists
        if Word.joins(:root).exists?
          root_results = Word.morphology_search(root: Word.joins(:root).first.root.value)
          puts "   ✅ Root-based search working: found #{root_results.count} words"
        else
          puts "   ⚠️  No root data available for testing"
        end
      else
        puts "   ❌ Word.morphology_search method not found"
      end
      
    rescue => e
      puts "   ❌ Morphology search test failed: #{e.message}"
    end
  end

  def self.test_admin_search_integration
    puts "\n5. Testing Admin Search Integration..."
    
    begin
      # Check if search helper methods exist
      if defined?(SearchHelper)
        puts "   ✅ SearchHelper module loaded"
        
        # Test helper methods
        helper_methods = %w[format_verse_result format_word_result extract_semantic_context]
        missing_helpers = helper_methods.reject { |method| SearchHelper.respond_to?(method) }
        
        if missing_helpers.empty?
          puts "   ✅ All search helper methods present"
        else
          puts "   ❌ Missing helper methods: #{missing_helpers.join(', ')}"
        end
      else
        puts "   ❌ SearchHelper module not found"
      end
      
      # Test if models have required search methods
      models_to_test = [Verse, Word, Translation]
      models_to_test.each do |model|
        if model.included_modules.include?(Searchable)
          puts "   ✅ #{model.name} includes Searchable concern"
        else
          puts "   ❌ #{model.name} missing Searchable concern"
        end
      end
      
    rescue => e
      puts "   ❌ Admin search integration test failed: #{e.message}"
    end
  end

  # Utility method to run performance benchmark
  def self.run_performance_test
    puts "\n🚀 Running Performance Test..."
    
    test_queries = [
      "الله",
      "رحمن", 
      "الحمد لله",
      "بسم الله الرحمن الرحيم"
    ]
    
    total_time = 0
    
    test_queries.each do |query|
      start_time = Time.current
      
      begin
        Verse.elasticsearch_search(query, per_page: 10)
        elapsed = Time.current - start_time
        total_time += elapsed
        
        puts "   Query '#{query}': #{(elapsed * 1000).round(2)}ms"
      rescue => e
        puts "   Query '#{query}': ERROR - #{e.message}"
      end
    end
    
    avg_time = total_time / test_queries.length
    puts "\n   Average response time: #{(avg_time * 1000).round(2)}ms"
    
    if avg_time < 1.0
      puts "   ✅ Performance target met (< 1 second)"
    else
      puts "   ⚠️  Performance target not met (> 1 second)"
    end
  end
  
  # Check if indices exist and have data
  def self.check_indices
    puts "\n📊 Checking Elasticsearch Indices..."
    
    models = [Verse, Word, Translation]
    
    models.each do |model|
      begin
        if defined?(Searchkick) && model.respond_to?(:searchkick_index)
          index = model.searchkick_index
          
          if index.exists?
            stats = index.stats
            doc_count = stats.dig('_all', 'total', 'docs', 'count') || 0
            puts "   #{model.name}: #{doc_count} documents indexed"
          else
            puts "   #{model.name}: Index not created"
          end
        else
          puts "   #{model.name}: Searchkick not configured"
        end
      rescue => e
        puts "   #{model.name}: Error checking index - #{e.message}"
      end
    end
  end
end

# Instructions for running the tests
puts <<~INSTRUCTIONS
  
  To run these validation tests, execute in Rails console:
  
  # Load this file
  load 'docs/search_validation_test.rb'
  
  # Run all tests
  SearchValidationTest.run_all_tests
  
  # Run specific tests
  SearchValidationTest.run_performance_test
  SearchValidationTest.check_indices
  
INSTRUCTIONS