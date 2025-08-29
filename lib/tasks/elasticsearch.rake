# frozen_string_literal: true

namespace :elasticsearch do
  desc 'Create and configure Elasticsearch indices'
  task setup: :environment do
    puts "Setting up Elasticsearch indices..."
    
    begin
      # Check if Elasticsearch is available
      unless defined?(Searchkick)
        puts "Error: Searchkick gem not loaded. Please install and configure Elasticsearch."
        exit 1
      end

      # Create indices
      [Verse, Word, Translation].each do |model|
        puts "Creating index for #{model.name}..."
        model.searchkick_index.delete if model.searchkick_index.exists?
        model.reindex
        puts "✓ #{model.name} index created and populated"
      end

      puts "Elasticsearch setup complete!"
      
    rescue => e
      puts "Error setting up Elasticsearch: #{e.message}"
      puts "Please ensure Elasticsearch is running and accessible."
      exit 1
    end
  end

  desc 'Reindex all searchable models'
  task reindex: :environment do
    puts "Reindexing all searchable models..."
    
    [Verse, Word, Translation].each do |model|
      puts "Reindexing #{model.name}..."
      start_time = Time.current
      
      model.reindex
      
      elapsed = Time.current - start_time
      puts "✓ #{model.name} reindexed in #{elapsed.round(2)} seconds"
    end
    
    puts "All models reindexed successfully!"
  end

  desc 'Reindex verses with full text and metadata'
  task reindex_verses: :environment do
    puts "Reindexing verses..."
    start_time = Time.current
    
    Verse.reindex
    
    elapsed = Time.current - start_time
    count = Verse.count
    puts "✓ #{count} verses reindexed in #{elapsed.round(2)} seconds"
  end

  desc 'Reindex words with morphological data'
  task reindex_words: :environment do
    puts "Reindexing words..."
    start_time = Time.current
    
    Word.reindex
    
    elapsed = Time.current - start_time
    count = Word.count
    puts "✓ #{count} words reindexed in #{elapsed.round(2)} seconds"
  end

  desc 'Reindex translations'
  task reindex_translations: :environment do
    puts "Reindexing translations..."
    start_time = Time.current
    
    Translation.reindex
    
    elapsed = Time.current - start_time
    count = Translation.count
    puts "✓ #{count} translations reindexed in #{elapsed.round(2)} seconds"
  end

  desc 'Check Elasticsearch status'
  task status: :environment do
    begin
      client = Searchkick.client
      health = client.cluster.health
      
      puts "Elasticsearch Status:"
      puts "  Cluster: #{health['cluster_name']}"
      puts "  Status: #{health['status']}"
      puts "  Nodes: #{health['number_of_nodes']}"
      puts "  Data Nodes: #{health['number_of_data_nodes']}"
      puts ""
      
      # Check indices
      [Verse, Word, Translation].each do |model|
        index = model.searchkick_index
        if index.exists?
          stats = index.stats
          doc_count = stats['_all']['total']['docs']['count']
          size = stats['_all']['total']['store']['size_in_bytes']
          
          puts "#{model.name} Index:"
          puts "  Documents: #{doc_count}"
          puts "  Size: #{(size / 1024.0 / 1024.0).round(2)} MB"
        else
          puts "#{model.name} Index: Not created"
        end
        puts ""
      end
      
    rescue => e
      puts "Error connecting to Elasticsearch: #{e.message}"
      exit 1
    end
  end

  desc 'Delete all indices'
  task delete_indices: :environment do
    puts "Deleting all Elasticsearch indices..."
    
    [Verse, Word, Translation].each do |model|
      index = model.searchkick_index
      if index.exists?
        index.delete
        puts "✓ #{model.name} index deleted"
      else
        puts "- #{model.name} index does not exist"
      end
    end
    
    puts "All indices deleted!"
  end

  desc 'Optimize indices for better search performance'
  task optimize: :environment do
    puts "Optimizing Elasticsearch indices..."
    
    [Verse, Word, Translation].each do |model|
      index = model.searchkick_index
      if index.exists?
        puts "Optimizing #{model.name} index..."
        index.refresh
        puts "✓ #{model.name} index optimized"
      end
    end
    
    puts "Index optimization complete!"
  end

  desc 'Run performance benchmarks'
  task benchmark: :environment do
    puts "Running Elasticsearch performance benchmarks..."
    
    queries = [
      "الله",
      "رحمن",
      "قرآن",
      "صلاة",
      "patience",
      "mercy",
      "الحمد لله رب العالمين"
    ]
    
    total_time = 0
    
    queries.each do |query|
      puts "\nTesting query: '#{query}'"
      
      start_time = Time.current
      results = Verse.elasticsearch_search(query, per_page: 10)
      elapsed = Time.current - start_time
      
      total_time += elapsed
      
      puts "  Results: #{results.count}"
      puts "  Time: #{(elapsed * 1000).round(2)}ms"
    end
    
    avg_time = total_time / queries.length
    puts "\nBenchmark Summary:"
    puts "  Total queries: #{queries.length}"
    puts "  Average response time: #{(avg_time * 1000).round(2)}ms"
    puts "  Total time: #{total_time.round(2)}s"
    
    if avg_time < 1.0
      puts "  ✓ Performance target met (< 1 second)"
    else
      puts "  ⚠ Performance target not met (> 1 second)"
    end
  end
end