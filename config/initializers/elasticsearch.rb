Elasticsearch::Model.client = Elasticsearch::Client.new(
  url: ENV['ELASTICSEARCH_URL'],
  user: ENV.fetch['ELASTICSEARCH_USER'],
  password: ENV['ELASTICSEARCH_PASSWORD'],
  retry_on_failure: true,
  log: Rails.env.development?
)