class Segments::Base < ActiveRecord::Base
  self.abstract_class = true
  self.establish_connection(
    adapter: 'sqlite3',
    database: "tmp/segments_database.db"
  )
end
