require 'csv'
require 'sqlite3'

module Exporter
  class BaseExporter
    attr_accessor :base_path, :export_file_path

    def initialize(base_path:, name:)
      @base_path = base_path

      FileUtils.mkdir_p(@base_path)
      @export_file_name = fix_file_name(name)
      @export_file_path = File.join(@base_path, "#{@export_file_name}")
      @db_statements = []
    end

    def create_sqlite_table(db_file_path, table_name, columns)
      @db ||= SQLite3::Database.new(db_file_path)
      column_names = columns.keys
      create_table_sql = "CREATE TABLE IF NOT EXISTS #{table_name} (#{columns.map { |name, type| "#{name} #{type}" }.join(', ')});"
      insert_sql = "INSERT INTO #{table_name} (#{column_names.join(', ')}) VALUES (#{column_names.map { '?' }.join(', ')});"

      @db.execute(create_table_sql)
      prepare_statement = @db.prepare(insert_sql)
      @db_statements << prepare_statement
      prepare_statement
    end

    def close_sqlite_table
      @db.close
      @db_statement.each &:close
    rescue SQLite3::Exception => e
      puts "Exception occurred #{e.message}"
    end

    def fix_file_name(name)
      name.downcase.to_param.parameterize.gsub(/[\s+_]/, '-')
    end
  end
end
