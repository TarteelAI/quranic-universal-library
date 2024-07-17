class AddSegmentLockToAyahRecitations < ActiveRecord::Migration[7.0]
  def up
    Verse.connection.add_column :recitations, :segment_locked, :boolean, default: true
  end

  def down
    Verse.connection.remove_column :recitations, :segment_locked
  end
end
