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
end
