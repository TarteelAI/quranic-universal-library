# Elasticsearch Search Setup Guide

## Prerequisites

### System Requirements
- Elasticsearch 7.10+ or 8.x
- Redis (for caching and job queues)
- Ruby 3.3.3 with Rails 7.0+
- PostgreSQL 14+ (for QUL data)

### Elasticsearch Installation

#### Using Docker (Recommended for Development)
```bash
# Pull and run Elasticsearch
docker run -d \
  --name elasticsearch \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
  docker.elastic.co/elasticsearch/elasticsearch:7.17.0

# Verify installation
curl http://localhost:9200
```

#### Using Package Manager (Production)
```bash
# Ubuntu/Debian
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update && sudo apt install elasticsearch

# Start service
sudo systemctl enable elasticsearch
sudo systemctl start elasticsearch
```

## Installation Steps

### 1. Install Dependencies

Add to your Gemfile (already done):
```ruby
gem 'elasticsearch-rails', '~> 7.2'
gem 'searchkick', '~> 5.3'
```

Install gems:
```bash
bundle install
```

### 2. Configure Environment Variables

Add to your `.env` file:
```env
# Elasticsearch configuration
ELASTICSEARCH_URL=http://localhost:9200
ELASTICSEARCH_HOST=localhost
ELASTICSEARCH_PORT=9200

# Redis for Searchkick caching
REDIS_URL=redis://localhost:6379/1
```

### 3. Initialize Elasticsearch Indices

```bash
# Check Elasticsearch status
rails elasticsearch:status

# Create and populate all indices
rails elasticsearch:setup

# Or create indices individually
rails elasticsearch:reindex_verses
rails elasticsearch:reindex_words
rails elasticsearch:reindex_translations
```

### 4. Verify Installation

```bash
# Check index status
rails elasticsearch:status

# Run performance benchmark
rails elasticsearch:benchmark

# Test search functionality
rails console
```

In Rails console:
```ruby
# Test basic search
results = Verse.elasticsearch_search("الحمد لله")
puts "Found #{results.count} results"

# Test morphology search
words = Word.morphology_search(part_of_speech: 'noun')
puts "Found #{words.count} nouns"

# Test semantic search
semantic_results = Verse.semantic_search("mercy")
puts "Found #{semantic_results.count} verses about mercy"
```

## Configuration Options

### Elasticsearch Settings

Edit `config/initializers/elasticsearch.rb`:

```ruby
# Custom index settings
Searchkick.index_suffix = Rails.env
Searchkick.search_timeout = 10
Searchkick.timeout = 15

# Client configuration
Searchkick.client_options = {
  retry_on_failure: 3,
  request_timeout: 30,
  transport_options: {
    ssl: { verify: false } # Only for development
  }
}
```

### Model Configuration

Each searchable model can be customized:

```ruby
class Verse < QuranApiRecord
  searchkick callbacks: :async,
             word_start: [:text_uthmani, :text_qpc_hafs],
             settings: {
               analysis: {
                 analyzer: {
                   arabic_analyzer: {
                     tokenizer: 'standard',
                     filter: ['lowercase', 'arabic_normalization']
                   }
                 }
               }
             }
end
```

## Production Deployment

### Elasticsearch Cluster Setup

For production, use a multi-node cluster:

```yaml
# elasticsearch.yml
cluster.name: qul-search
node.name: qul-search-1
network.host: 0.0.0.0
discovery.seed_hosts: ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
cluster.initial_master_nodes: ["qul-search-1", "qul-search-2", "qul-search-3"]

# Security
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
```

### Environment Variables

```env
# Production Elasticsearch
ELASTICSEARCH_URL=https://user:pass@elasticsearch.qul.com:9200
ELASTICSEARCH_SSL_VERIFY=true

# Cluster settings
ES_CLUSTER_NAME=qul-search-production
ES_NODES=elasticsearch1.qul.com:9200,elasticsearch2.qul.com:9200
```

### Index Management

```bash
# Production indexing (use background jobs)
RAILS_ENV=production rails elasticsearch:reindex

# Monitor indexing progress
RAILS_ENV=production rails console
> Searchkick.reindex_status
```

## Monitoring and Maintenance

### Health Checks

```bash
# Elasticsearch cluster health
curl "localhost:9200/_cluster/health?pretty"

# Index statistics
curl "localhost:9200/quran_verses_production/_stats?pretty"

# Node information
curl "localhost:9200/_nodes/stats?pretty"
```

### Performance Monitoring

Add to your monitoring dashboard:

```ruby
# In your monitoring service
module ElasticsearchMonitoring
  def self.check_health
    health = Searchkick.client.cluster.health
    {
      status: health['status'],
      nodes: health['number_of_nodes'],
      response_time: measure_search_time
    }
  end

  def self.measure_search_time
    start_time = Time.current
    Verse.search("الله", limit: 1)
    (Time.current - start_time) * 1000
  end
end
```

### Backup and Recovery

```bash
# Create snapshot repository
curl -X PUT "localhost:9200/_snapshot/qul_backups" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/path/to/backup"
  }
}'

# Create snapshot
curl -X PUT "localhost:9200/_snapshot/qul_backups/snapshot_1"

# Restore from snapshot
curl -X POST "localhost:9200/_snapshot/qul_backups/snapshot_1/_restore"
```

## Troubleshooting

### Common Issues

1. **Elasticsearch not starting**
   ```bash
   # Check logs
   sudo journalctl -u elasticsearch
   
   # Increase JVM heap size
   export ES_JAVA_OPTS="-Xms1g -Xmx1g"
   ```

2. **Index creation fails**
   ```bash
   # Check disk space
   df -h
   
   # Check Elasticsearch logs
   tail -f /var/log/elasticsearch/elasticsearch.log
   ```

3. **Search queries timeout**
   ```ruby
   # Increase timeout in initializer
   Searchkick.search_timeout = 30
   ```

4. **Memory issues during indexing**
   ```bash
   # Index in smaller batches
   Verse.reindex(async: true, batch_size: 100)
   ```

### Performance Optimization

1. **Optimize index settings**
   ```json
   {
     "settings": {
       "number_of_shards": 3,
       "number_of_replicas": 1,
       "refresh_interval": "30s"
     }
   }
   ```

2. **Use field-specific searches**
   ```ruby
   # More efficient
   Verse.search(query, fields: [:text_uthmani])
   
   # Less efficient
   Verse.search(query)
   ```

3. **Implement result caching**
   ```ruby
   def cached_search(query)
     Rails.cache.fetch("search:#{query.hash}", expires_in: 1.hour) do
       Verse.search(query)
     end
   end
   ```

## API Usage Examples

### Creating API Client

```ruby
# In Rails console or seeds
api_client = ApiClient.create!(
  name: "Mobile App",
  request_quota: 10000,
  active: true
)

puts "API Key: #{api_client.api_key}"
```

### Testing API Endpoints

```bash
# Set your API key
API_KEY="your_generated_api_key"

# Test general search
curl -H "X-API-Key: $API_KEY" \
  "http://localhost:3000/api/v1/search?q=الله"

# Test morphology search
curl -H "X-API-Key: $API_KEY" \
  "http://localhost:3000/api/v1/search/morphology?part_of_speech=noun"

# Test semantic search
curl -H "X-API-Key: $API_KEY" \
  "http://localhost:3000/api/v1/search/semantic?q=mercy"
```

## Development Tips

1. **Use async indexing in development**
   ```ruby
   # In development.rb
   config.searchkick = { callbacks: :async }
   ```

2. **Reset indices during development**
   ```bash
   rails elasticsearch:delete_indices
   rails elasticsearch:setup
   ```

3. **Debug search queries**
   ```ruby
   # Enable query logging
   Searchkick.client.transport.logger = Logger.new(STDOUT)
   ```

4. **Test without Elasticsearch**
   ```ruby
   # Fallback to database search
   class Verse
     def self.elasticsearch_search(query, options = {})
       where("text_uthmani ILIKE ?", "%#{query}%")
     end
   end
   ```

## Security Considerations

1. **Enable authentication in production**
   ```yaml
   # elasticsearch.yml
   xpack.security.enabled: true
   ```

2. **Use HTTPS for API endpoints**
   ```ruby
   # In production.rb
   config.force_ssl = true
   ```

3. **Implement proper rate limiting**
   ```ruby
   # Already implemented in ApiClient model
   ```

4. **Sanitize search inputs**
   ```ruby
   def sanitize_query(query)
     query.gsub(/[<>]/, '').strip
   end
   ```

---

For support or questions about the search implementation, contact the QUL development team.