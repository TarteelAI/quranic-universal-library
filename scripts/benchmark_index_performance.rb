require 'sqlite3'
require 'benchmark/ips'

DB_WITHOUT_INDEX = SQLite3::Database.new('quran-data-without-indexes.sqlite')
DB_WITH_INDEX = SQLite3::Database.new('quran-data.sqlite')
QUERY = 'SELECT * FROM words WHERE surah_number = ? AND ayah_number = ?'
TEST_SURAH_NUMBER = 2
TEST_AYAH_NUMBER = 255

def query_db(db, surah_number, ayah_number)
  db.results_as_hash = true
  db.execute(QUERY, surah_number, ayah_number)
end

Benchmark.ips(30) do |x|
  x.report("Without Index:") do
    50.times do
      query_db(DB_WITHOUT_INDEX, TEST_SURAH_NUMBER, TEST_AYAH_NUMBER)
    end
  end

  x.report("With Index:") do
    50.times do
      query_db(DB_WITH_INDEX, TEST_SURAH_NUMBER, TEST_AYAH_NUMBER)
    end
  end
end
