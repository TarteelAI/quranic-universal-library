# frozen_string_literal: true

# Elasticsearch configuration for Quran search
if ENV['ELASTICSEARCH_URL'].present?
  Elasticsearch::Model.client = Elasticsearch::Client.new(
    url: ENV['ELASTICSEARCH_URL'],
    log: Rails.env.development?
  )
else
  # Default configuration for development
  Elasticsearch::Model.client = Elasticsearch::Client.new(
    host: ENV.fetch('ELASTICSEARCH_HOST', 'localhost'),
    port: ENV.fetch('ELASTICSEARCH_PORT', 9200),
    log: Rails.env.development?
  )
end

# Searchkick configuration
Searchkick.redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))

# Configure search settings
Searchkick.search_timeout = 10
Searchkick.timeout = 15
Searchkick.models = []

# Index naming for different environments
Searchkick.index_suffix = Rails.env unless Rails.env.production?

# Custom analyzer for Arabic text
Searchkick.client_options = {
  retry_on_failure: 3,
  request_timeout: 30
}