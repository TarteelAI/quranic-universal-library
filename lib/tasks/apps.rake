# frozen_string_literal: true

namespace :apps do
  desc 'Import config/apps.yml as published apps, once: entries that already have a row are skipped'
  task import: :environment do
    puts "apps:import: #{AppDirectory::Import.run} rows created"
  end
end
