# frozen_string_literal: true

namespace :db do
  desc 'Download and load the quran_dev mini dump if the database is empty'
  task load_quran_dump: :environment do
    dump_url = 'https://static-cdn.tarteel.ai/qul/mini-dumps/mini_quran_dev.sql.zip'
    db_name = 'quran_dev'
    db_host = ENV.fetch('DB_HOST', 'localhost')
    db_user = ENV.fetch('DB_USERNAME', 'postgres')
    db_password = ENV.fetch('DB_PASSWORD', nil)

    # Check if quran_dev already has data
    begin
      conn = PG.connect(dbname: db_name, host: db_host, user: db_user, password: db_password)
      res = conn.exec("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'quran' AND table_name = 'chapters') AS has_table")
      has_table = res[0]['has_table'] == 't'

      if has_table
        result = conn.exec('SELECT count(*) FROM quran.chapters')[0]['count'].to_i
      else
        result = 0
      end
      conn.close
    rescue PG::Error => e
      puts "[db:load_quran_dump] Could not connect to #{db_name}: #{e.message}"
      puts '[db:load_quran_dump] Skipping dump load. See README for manual instructions.'
      next
    end

    if result > 0
      puts "[db:load_quran_dump] #{db_name} already has #{result} chapters. Skipping."
      next
    end

    require 'tmpdir'

    Dir.mktmpdir('quran_dump') do |tmpdir|
      zip_path = File.join(tmpdir, 'mini_quran_dev.sql.zip')

      puts "[db:load_quran_dump] Downloading dump from #{dump_url}..."
      system('wget', '-q', '--show-progress', '-O', zip_path, dump_url) || begin
        puts '[db:load_quran_dump] Download failed. See README for manual instructions.'
        next
      end

      puts '[db:load_quran_dump] Extracting...'
      system('unzip', '-o', '-d', tmpdir, zip_path) || begin
        puts '[db:load_quran_dump] Extraction failed.'
        next
      end

      sql_file = Dir.glob(File.join(tmpdir, '*.sql')).first
      unless sql_file
        puts '[db:load_quran_dump] No SQL file found in archive.'
        next
      end

      puts "[db:load_quran_dump] Loading #{File.basename(sql_file)} into #{db_name}..."
      env = db_password ? { 'PGPASSWORD' => db_password } : {}
      success = system(env, 'psql', '-h', db_host, '-U', db_user, '-d', db_name, '-f', sql_file,
                        out: '/dev/null')

      if success
        puts '[db:load_quran_dump] Dump loaded successfully.'
      else
        puts '[db:load_quran_dump] psql returned errors. Check database state manually.'
      end
    end
  end
end

# Hook into db:setup so it runs after create + schema:load + seed
Rake::Task['db:setup'].enhance do
  Rake::Task['db:load_quran_dump'].invoke
end
