# frozen_string_literal: true

module Utils
  class DbBackup
    include ActionView::Helpers::NumberHelper
    STORAGE_PATH = "#{Rails.root}/tmp/database_dumps".freeze
    attr_reader :config, :backup_name

    def self.run(tag)
      databases.each do |key, config|
        Utils::DbBackup.new(key, config).run(tag)
      end

      FileUtils.rm_rf(STORAGE_PATH)
    end

    def initialize(key, db_config)
      @backup_name = key
      @config = db_config
    end

    def run(tag)
      require 'fileutils'
      FileUtils.mkdir_p STORAGE_PATH

      # create the dump
      system pg_dump_command

      compress
      upload(tag)
      clean_up
    end

    def upload(tag)
      # Upload file to google cloud storage
      backup      = DatabaseBackup.new(database_name: backup_name)
      backup.size = number_to_human_size(File.size(dump_file_name))
      backup.file = Rails.root.join(dump_file_name).open
      backup.tag  = tag

      backup.save
    end

    def clean_up; end

    def compress
      `bzip2 #{dump_file_name}`

      # return the db file path
      @dump_filename = "#{dump_file_name}.bz2"
    end

    protected

    def pg_dump_command
      password_argument = "PGPASSWORD='#{config[:password]}'" if config[:password].present?
      host_argument     = "--host=#{config[:host]}" if config[:host].present?
      port_argument     = "--port=#{config[:port]}" if config[:port].present?
      username_argument = "--username=#{config[:username]}" if config[:username].present?

      # '--schema=public', # only public schema

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
      @dump_filename ||= "#{STORAGE_PATH}/#{backup_name}-#{Time.now.strftime('%b-%d-%Y-%I:%M-%P')}.sql"
    end

    def self.databases
      {
        api_staging: {
          host: ENV['QURAN_API_DB_HOST'],
          port:  ENV['QURAN_API_DB_PORT'],
          database:  ENV['QURAN_API_DB_NAME'],
          username:ENV['QURAN_API_DB_USERNAME'],
          password: ENV['QURAN_API_DB_PASSWORD']
        },
        cms: {
          host: ENV['CMS_DB_HOST'],
          port: ENV['CMS_DB_PORT'],
          database: ENV['CMS_DB_NAME'],
          password: ENV['CMS_DB_PASSWORD'],
          username: ENV['CMS_DB_USERNAME']
        }
      }
    end
  end
end
