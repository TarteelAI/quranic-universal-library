# frozen_string_literal: true

module Utils
  class DbBackup
    include ActionView::Helpers::NumberHelper
    STORAGE_PATH = "#{Rails.root}/tmp/database_dumps".freeze
    attr_reader :config, :backup_name
    attr_accessor :options

    def self.run(tag, options: {})
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
      require 'fileutils'
      FileUtils.mkdir_p STORAGE_PATH

      # create the dump
      command = pg_dump_command
      puts "Running sql export \n #{command} \n\n"
      system(command)

      if export_binary?
        binary_command = binary_dump_command
        puts "Running binary export \n #{binary_command} \n\n"
        system(binary_command)
      end

      if Rails.env.production?
        compress
        upload(tag)
        clean_up
      end
    end

    def upload(tag)
      # Upload file to google cloud storage
      backup = DatabaseBackup.new(database_name: backup_name)
      backup.size = number_to_human_size(File.size(dump_file_name))
      backup.file = Rails.root.join(dump_file_name).open
      backup.tag = tag

      backup.save

      if export_binary?
        binary_backup = DatabaseBackup.new(database_name: "#{backup_name}_binary")
        binary_backup.size = number_to_human_size(File.size(binary_dump_file_name))
        binary_backup.file = Rails.root.join(binary_dump_file_name).open
        binary_backup.tag = tag

        binary_backup.save
      end
    end

    def clean_up
      FileUtils.rm_rf(STORAGE_PATH)
    end

    def compress
      `bzip2 #{dump_file_name}`

      # return the db file path
      @dump_filename = "#{dump_file_name}.bz2"

      if export_binary?
        `bzip2 #{binary_dump_file_name}`
        @binary_dump_filename = "#{binary_dump_file_name}.bz2"
      end
    end

    protected

    def export_binary?
      Rails.env.development? || options[:binary]
    end

    def binary_dump_command
      # pg_dump --host localhost --port 5432 --username <USERNAME> -b -E UTF-8 --no-owner --no-privileges --no-tablespaces --data-only -F c -Z 9 -f <BACKUPFILENAME> <DATABASENAME>
      # pg_restore --host localhost --port 5432 --username <USERNAME> --dbname <DATABASENAME> --no-owner --no-privileges --no-tablespaces --no-acl -v "<BACKUPFILENAME>"
      # pg_restore -U your_username -h your_host -p your_port -d your_database_name -v output_file.dump

      password_argument = "PGPASSWORD='#{config['password']}'" if config['password'].present?
      host_argument = "--host=#{config['host']}" if config['host'].present?
      port_argument = "--port=#{config['port']}" if config['port'].present?
      username_argument = "--username=#{config['username']}" if config['username'].present?

      [password_argument, # pass the password to pg_dump (if any)
       'pg_dump', # the pg_dump command
       '-b', # Include large objects in the dump. This is the default behavior except when --schema, --table, or --schema-only is specified. The -b switch is therefore only useful to add large objects to dumps where a specific schema or table has been requested. Note that blobs are considered data and therefore will be included when --data-only is used, but not when --schema-only is.
       '-E UTF-8', # Encoding
       "-f #{binary_dump_file_name}", # output to the dump file
       '--no-owner', # do not output commands to set ownership of objects
       '--no-privileges', # prevent dumping of access privileges
       '--no-tablespaces', # Do not output commands to select tablespaces. With this option, all objects will be created in whichever tablespace is the default during restore.
       '-F c', # Output a custom-format archive suitable for input into pg_restore. Together with the directory output format, this is the most flexible output format in that it allows manual selection and reordering of archived items during restore. This format is also compressed by default
       '-Z 9', # Specify the compression level to use. Zero means no compression. For the custom archive format, this specifies compression of individual table-data segments, and the default is to compress at a moderate level. For plain text output, setting a nonzero compression level causes the entire output file to be compressed, as though it had been fed through gzip; but the default is not to compress. The tar archive format currently does not support compression at all.
       '--clean', # Add drop tables if exist in dump, pg_restore will drop tables and have clean restore
       host_argument, # the hostname to connect to (if any)
       port_argument, # the port to connect to (if any)
       username_argument, # the username to connect as (if any)
       config[:database] # the name of the database to dump
      ].join(' ')
    end

    def pg_dump_command
      password_argument = "PGPASSWORD='#{config[:password]}'" if config[:password].present?
      host_argument = "--host=#{config[:host]}" if config[:host].present?
      port_argument = "--port=#{config[:port]}" if config[:port].present?
      username_argument = "--username=#{config[:username]}" if config[:username].present?

      [password_argument, # pass the password to pg_dump (if any)
       'pg_dump', # the pg_dump command
       "--file='#{dump_file_name}'", # output to the dump.sql file
       '--no-owner', # do not output commands to set ownership of objects
       '--no-privileges', # prevent dumping of access privileges
       host_argument, # the hostname to connect to (if any)
       port_argument, # the port to connect to (if any)
       username_argument, # the username to connect as (if any)
       config[:database] # the name of the database to dump
      ].join(' ')
    end

    def dump_file_name
      @dump_filename ||= "#{STORAGE_PATH}/#{backup_name}-sql-#{Time.now.strftime('%b-%d-%Y-%I-%M-%P')}.sql"
    end

    def binary_dump_file_name
      @binary_dump_filename ||= "#{STORAGE_PATH}/#{backup_name}-binary-#{Time.now.strftime('%b-%d-%Y-%I-%M-%P')}"
    end

    def self.databases
      {
        api_staging: {
          host: ENV['QURAN_API_DB_HOST'],
          port: ENV['QURAN_API_DB_PORT'],
          database: ENV['QURAN_API_DB_NAME'] || 'quran_dev',
          username: ENV['QURAN_API_DB_USERNAME'],
          password: ENV['QURAN_API_DB_PASSWORD']
        }.compact_blank,
        cms: {
          host: ENV['CMS_DB_HOST'],
          port: ENV['CMS_DB_PORT'],
          database: ENV['CMS_DB_NAME'] || 'quran_community_tarteel',
          password: ENV['CMS_DB_PASSWORD'],
          username: ENV['CMS_DB_USERNAME']
        }.compact_blank
      }
    end
  end
end
