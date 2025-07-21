class SegmentStats::Base < ActiveRecord::Base
  self.abstract_class = true
  self.establish_connection(
    adapter: 'sqlite3',
    database: "db/segments_database.db"
  )
end
