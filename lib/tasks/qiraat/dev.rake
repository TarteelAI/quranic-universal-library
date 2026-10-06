# Development-only helpers for the multi-riwayah work.
#
# The riwayah migrations and backfills run against a clone of the dev Quran
# database (quran_dev_qirat) so the day-to-day copy is never written to.
#
#   rake qiraat:dev:clone   # create quran_dev_qirat from quran_dev (fails if it exists)
#   rake qiraat:dev:reset   # drop quran_dev_qirat and clone it again
#
# Both use `createdb -T`, which needs no open connections to the template
# database: stop the app and Sidekiq before running them.
namespace :qiraat do
  namespace :dev do
    SOURCE_DB = ENV.fetch('QIRAAT_SOURCE_DB', 'quran_dev')
    CLONE_DB = ENV.fetch('QIRAAT_CLONE_DB', 'quran_dev_qirat')

    def qiraat_dev_guard!
      abort 'qiraat:dev tasks are development-only' unless Rails.env.development?
    end

    def qiraat_db_exists?(name)
      out = `psql -d postgres -Atc "select 1 from pg_database where datname = '#{name}'"`.strip
      out == '1'
    end

    def qiraat_clone!
      puts "Cloning #{SOURCE_DB} -> #{CLONE_DB} (template copy)"
      system('createdb', '-T', SOURCE_DB, CLONE_DB) || abort('createdb failed')
      size = `psql -d postgres -Atc "select pg_size_pretty(pg_database_size('#{CLONE_DB}'))"`.strip
      puts "Done: #{CLONE_DB} is #{size}"
    end

    desc "Create #{CLONE_DB} as a copy of #{SOURCE_DB}"
    task clone: :environment do
      qiraat_dev_guard!
      abort "#{CLONE_DB} already exists; use qiraat:dev:reset to rebuild it" if qiraat_db_exists?(CLONE_DB)
      qiraat_clone!
    end

    desc "Drop #{CLONE_DB} and clone it again from #{SOURCE_DB}"
    task reset: :environment do
      qiraat_dev_guard!
      if qiraat_db_exists?(CLONE_DB)
        puts "Dropping #{CLONE_DB}"
        ActiveRecord::Base.connection_handler.clear_all_connections!
        system('dropdb', '--force', CLONE_DB) || abort('dropdb failed')
      end
      qiraat_clone!
    end
  end
end
