# Local development and test databases are copies of a production snapshot, made by
# bin/snapshot-clones. Each copy carries a database comment, so code that writes fake
# data or runs specs can tell a copy from the snapshot it was made from.
module SnapshotClone
  MARKER = 'qul snapshot clone'

  def self.comment_for(source_database)
    "#{MARKER} of #{source_database}"
  end

  def self.clone?(connection)
    comment = connection.select_value(<<~SQL)
      SELECT shobj_description(oid, 'pg_database') FROM pg_database WHERE datname = current_database()
    SQL
    comment.to_s.start_with?(MARKER)
  end
end
