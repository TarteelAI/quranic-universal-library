namespace :db do
  desc "Apply db tasks in specific databases, rake db:run_task[db:migrate, quran_api] applies db:migrate on the database defined as quran_api in databases.yml"
  task :run_task, [:task, :database] => [:environment] do |t, args|
    require 'activerecord'
    puts "Applying #{args.task} on #{args.database}"
    ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[args.database])
    Rake::Task[args.task].invoke
  end

  task run_api_migrations: :environment do
    ActiveRecord::Base.establish_connection(Rails.env.development? ? :quran_api_db_dev : :quran_api_db)
    ActiveRecord::Migrator.migrations_paths = ['db/migrate/api']
    ActiveRecord::Tasks::DatabaseTasks.migrate
  end
end
