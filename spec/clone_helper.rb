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
require 'inertia_rails/rspec'
require_relative 'support/ssr_server'

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

  # The page group setting (PageGroups) for one example group: `page_groups: %w[catalog]` serves
  # the catalog with the new pages, `page_groups: []` serves every group with the old views.
  config.around(:example, :page_groups) do |example|
    original = ENV.fetch('QUL_PAGE_GROUPS', nil)
    ENV['QUL_PAGE_GROUPS'] = Array(example.metadata[:page_groups]).join(',')
    example.run
  ensure
    ENV['QUL_PAGE_GROUPS'] = original
  end

  # The download mode setting (DownloadMode) for one example group: `download_mode: 'public'`.
  config.around(:example, :download_mode) do |example|
    original = ENV.fetch('QUL_DOWNLOAD_MODE', nil)
    ENV['QUL_DOWNLOAD_MODE'] = example.metadata[:download_mode]
    example.run
  ensure
    ENV['QUL_DOWNLOAD_MODE'] = original
  end
end
