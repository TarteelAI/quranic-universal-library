# Boots Rails for specs that run against clones of the local snapshot (bin/snapshot-clones).
# Unlike the generated rails_helper it never loads, checks or migrates the schema: the
# clones are the schema. It refuses to run against a database that is not a clone.
ENV['RAILS_ENV'] = 'test'
require_relative '../config/boot'
require 'dotenv'
# dotenv loads nothing in test; the clone connection lives in this file.
Dotenv.load(File.expand_path('../.env.test.local', __dir__))
require_relative '../config/environment'
require 'rspec/rails'

RSpec.configure do |config|
  config.before(:suite) do
    [ApplicationRecord, QulQuranRecord].each do |model|
      connection = model.connection
      next if SnapshotClone.clone?(connection)

      abort "#{connection.current_database} is not a snapshot clone. Run bin/snapshot-clones first."
    end
  end

  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!

  # config/initializers/hosts.rb limits the allowed hosts in every environment.
  config.before(type: :request) { host! 'localhost' }
end
