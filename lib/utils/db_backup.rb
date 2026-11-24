# frozen_string_literal: true

module Utils
  class DbBackup
    include ActionView::Helpers::NumberHelper
    STORAGE_PATH = "#{Rails.root}/tmp/database_dumps".freeze

    attr_accessor :config,
                :backup_name,
                :options

    def self.run(tag, options: { binary: false })
      FileUtils.mkdir_p(STORAGE_PATH)

      databases.each do |key, config|
        Utils::DbBackup.new(key, config, options).run(tag)
      end
    end

    def initialize(key, db_config, options = { binary: false })
      @backup_name = key
      @config = db_config
      @options = options
    end

    def run(tag)
      FileUtils.mkdir_p(STORAGE_PATH)

      # Create the dump
      command = pg_dump_command
      puts "Running sql export: #{command.join(' ')}"
      system(pg_env, *command)

      if export_binary?
        binary_command = binary_dump_command
        puts "Running binary export: #{binary_command.join(' ')}"
        system(pg_env, *binary_command)
      end

      if Rails.env.production?
        compress
        upload(tag)
        clean_up
      end
    end

    def upload(tag)
      backup = DatabaseBackup.new(database_name: backup_name)
      backup.size = number_to_human_size(File.size(dump_file_name))
      backup.tag = tag

      backup.backup_file.attach(
        io: File.open(dump_file_name),
        filename: File.basename(dump_file_name),
        content_type: 'application/x-bzip2'
      )

      backup.save

      if export_binary?
        binary_backup = DatabaseBackup.new(database_name: "#{backup_name}_binary")
        binary_backup.size = number_to_human_size(File.size(binary_dump_file_name))
        binary_backup.tag = tag

        binary_backup.backup_file.attach(
          io: File.open(binary_dump_file_name),
          filename: File.basename(binary_dump_file_name),
          content_type: 'application/x-bzip2'
        )

        binary_backup.save
      end
    end

    def clean_up
      FileUtils.rm_rf(STORAGE_PATH)
    end

    def compress
      system('bzip2', dump_file_name)

      @dump_filename = "#{dump_file_name}.bz2"

      if export_binary?
        system('bzip2', binary_dump_file_name)
        @binary_dump_filename = "#{binary_dump_file_name}.bz2"
      end
    end

    protected

    def export_binary?
      options[:binary]
    end

    def pg_env
      config[:password].present? ? { 'PGPASSWORD' => config[:password].to_s } : {}
    end

    def connection_arguments
      [
        ("--host=#{config[:host]}" if config[:host].present?),
        ("--port=#{config[:port]}" if config[:port].present?),
        ("--username=#{config[:username]}" if config[:username].present?)
      ].compact
    end

    # pg_restore --host localhost --port 5432 --username <USERNAME> --dbname <DATABASENAME> --no-owner --no-privileges --no-tablespaces --no-acl -v "<BACKUPFILENAME>"
    def binary_dump_command
      [
        'pg_dump',
        '-b', # include large objects
        '-E', 'UTF-8',
        '-f', binary_dump_file_name,
        '--no-owner',
        '--no-privileges',
        '--no-tablespaces',
        '-F', 'c', # custom format for pg_restore
        '-Z', '9',
        '--clean', # drop tables on restore
        *connection_arguments,
        config[:database].to_s
      ]
    end

    def pg_dump_command
      [
        'pg_dump',
        "--file=#{dump_file_name}",
        '--no-owner',
        '--no-privileges',
        *connection_arguments,
        config[:database].to_s
      ]
    end

    def dump_file_name
      @dump_filename ||= "#{STORAGE_PATH}/#{backup_name}-sql-#{Time.now.strftime('%b-%d-%Y-%I-%M-%P')}.sql"
    end

    def binary_dump_file_name
      @binary_dump_filename ||= "#{STORAGE_PATH}/#{backup_name}-binary-#{Time.now.strftime('%b-%d-%Y-%I-%M-%P')}"
    end

    # Read connection settings from database.yml (via the models' connections)
    # so the backup always targets the same databases as the app.
    def self.databases
      {
        quran_content: connection_config(QulQuranRecord),
        cms: connection_config(ApplicationRecord)
      }
    end

    def self.connection_config(model)
      model.connection_db_config.configuration_hash
           .slice(:host, :port, :database, :username, :password)
           .compact_blank
    end
  end
end
