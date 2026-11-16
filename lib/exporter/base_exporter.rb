require 'csv'
require 'sqlite3'

module Exporter
  class BaseExporter
    attr_accessor :base_path,
                  :export_file_path,
                  :resource_content

    def initialize(base_path:, name: nil, resource_content: nil)
      @base_path = base_path

      FileUtils.mkdir_p(@base_path)
      @resource_content = resource_content
      @export_file_name = fix_file_name(name || resource_content.sqlite_file_name)
      @export_file_path = File.join(@base_path, "#{@export_file_name}")
      @db_statements = []
      @dbs = []
    end

    def create_sqlite_table(db_file_path, table_name, columns)
      db = SQLite3::Database.new(db_file_path)
      db.execute('PRAGMA synchronous = OFF;')
      db.execute('PRAGMA journal_mode = MEMORY;')
      column_names = columns.keys
      create_table_sql = "CREATE TABLE #{table_name} (#{columns.map { |name, type| "#{name} #{type}" }.join(', ')});"
      insert_sql = "INSERT INTO #{table_name} (#{column_names.join(', ')}) VALUES (#{column_names.map { '?' }.join(', ')});"

      # The .db survives between exports; drop the table (not the file, which may hold others).
      db.execute("DROP TABLE IF EXISTS #{table_name};")
      db.execute(create_table_sql)
      prepare_statement = db.prepare(insert_sql)
      @db_statements << prepare_statement
      @dbs << db
      prepare_statement
    end

    def close_sqlite_table
      (@db_statements + @dbs).each do |resource|
        resource.close
      rescue SQLite3::Exception => e
        puts "Exception occurred #{e.message}"
      end

      @db_statements.clear
      @dbs.clear
    end

    def fix_file_name(name)
      name.downcase.to_param.parameterize.gsub(/[\s+_]/, '-')
    end

    def write_json(file, data)
      File.open(file, 'w') do |f|
        f << JSON.generate(data, { state: JsonNoEscapeHtmlState.new })
      end
    end

    def todo
      write_json "pending.json", "We'll publish this soon!"

      "pending.json"
    end
  end
end
