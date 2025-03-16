require 'sqlite3'
require 'benchmark'

file_path = "benchmark_test.db"
table_name = "ayah_timings"

db = SQLite3::Database.new(file_path)
db.execute("DROP TABLE IF EXISTS #{table_name}")

db.execute("CREATE TABLE #{table_name} (
    reciter INTEGER,
    surah_number INTEGER,
    ayah_number INTEGER,
    timings TEXT)")

puts "Inserting data..."
db.transaction do
  (6336 * 10).times do |i|
    db.execute("INSERT INTO #{table_name} (reciter, surah_number, ayah_number, timings) VALUES (?, ?, ?, ?)",
               [rand(1..10), rand(1..114), rand(1..286), "0,1,2"])
  end
end
puts "Data insertion completed."

query = "SELECT * FROM #{table_name} WHERE reciter = 5 AND surah_number = 2 AND ayah_number = 255"

puts "Running benchmark without index..."
time_without_index = Benchmark.measure do
  100.times { db.execute(query) }
end
puts "Time without index: #{time_without_index}"

puts "Creating indexes..."
db.execute("CREATE INDEX idx_reciter_surah_ayah ON #{table_name} (reciter, surah_number, ayah_number)")

puts "Running benchmark with index..."
time_with_index = Benchmark.measure do
  100.times { db.execute(query) }
end

puts "Time with index: #{time_with_index}"
puts db.execute("EXPLAIN QUERY PLAN #{query}").inspect

db.close
File.delete(file_path) if File.exist?(file_path)

# Results:
# Running benchmark without index...
# Time without index:   0.026722   0.000512   0.027234 (  0.027240)
# Creating indexes...
# Running benchmark with index...
# Time with index:   0.001238   0.000429   0.001667 (  0.001698)
# dropped from ~27ms to ~1.7ms with the index that's 15x faster with the index

# For 10 reciters time dropped from ~264ms to ~1.8ms, making it ~145x faster