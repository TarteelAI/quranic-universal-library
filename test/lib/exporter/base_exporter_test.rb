require 'minitest/autorun'
require 'tmpdir'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/to_param'
require 'active_support/core_ext/string/inflections'
require_relative '../../../lib/exporter/base_exporter'

class BaseExporterTest < Minitest::Test
  COLUMNS = { ayah_key: 'TEXT', text: 'TEXT' }.freeze

  def export(dir, rows)
    exporter = Exporter::BaseExporter.new(base_path: dir, name: 'tafsir')
    statement = exporter.create_sqlite_table(File.join(dir, 'tafsir.db'), 'tafsir', COLUMNS)
    rows.each { |row| statement.execute(row) }
  end

  def rows_in(dir)
    db = SQLite3::Database.new(File.join(dir, 'tafsir.db'))
    db.execute('SELECT ayah_key, text FROM tafsir ORDER BY rowid')
  ensure
    db&.close
  end

  def test_re_export_replaces_rows_from_the_previous_export
    Dir.mktmpdir do |dir|
      export(dir, [['1:1', 'old text']])
      export(dir, [['1:1', 'new text']])

      assert_equal [['1:1', 'new text']], rows_in(dir)
    end
  end

  def test_tables_written_to_the_same_file_in_one_export_are_kept
    Dir.mktmpdir do |dir|
      exporter = Exporter::BaseExporter.new(base_path: dir, name: 'layout')
      path = File.join(dir, 'layout.db')
      exporter.create_sqlite_table(path, 'pages', { page: 'INTEGER' }).execute([1])
      exporter.create_sqlite_table(path, 'info', { name: 'TEXT' }).execute(['madani'])

      db = SQLite3::Database.new(path)

      assert_equal [[1]], db.execute('SELECT page FROM pages')
      assert_equal [['madani']], db.execute('SELECT name FROM info')
    ensure
      db&.close
    end
  end

  def test_create_sqlite_table_uses_fast_write_pragmas
    Dir.mktmpdir do |dir|
      exporter = Exporter::BaseExporter.new(base_path: dir, name: 'tafsir')
      statement = exporter.create_sqlite_table(File.join(dir, 'tafsir.db'), 'tafsir', COLUMNS)
      db = statement.instance_variable_get(:@connection)

      assert_equal 0, db.get_first_value('PRAGMA synchronous')
      assert_equal 'memory', db.get_first_value('PRAGMA journal_mode')
    ensure
      statement&.close
      db&.close
    end
  end

  def test_close_sqlite_table_closes_resources_and_is_idempotent
    Dir.mktmpdir do |dir|
      exporter = Exporter::BaseExporter.new(base_path: dir, name: 'tafsir')
      statement = exporter.create_sqlite_table(File.join(dir, 'tafsir.db'), 'tafsir', COLUMNS)
      db = statement.instance_variable_get(:@connection)
      exporter.define_singleton_method(:sleep) { |*| }

      exporter.close_sqlite_table

      assert statement.closed?
      assert db.closed?
      exporter.close_sqlite_table
      assert_empty exporter.instance_variable_get(:@db_statements)
      assert_empty exporter.instance_variable_get(:@dbs)
    end
  end

  def test_close_sqlite_table_does_not_sleep
    Dir.mktmpdir do |dir|
      exporter = Exporter::BaseExporter.new(base_path: dir, name: 'tafsir')
      exporter.create_sqlite_table(File.join(dir, 'tafsir.db'), 'tafsir', COLUMNS)
      slept = false
      exporter.define_singleton_method(:sleep) { |*| slept = true }

      exporter.close_sqlite_table

      refute slept
    end
  end
end
