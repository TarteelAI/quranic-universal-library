class AddSegmentLockToAyahRecitations < ActiveRecord::Migration[7.0]
  def up
    c = Verse.connection
    c.add_column :recitations, :segment_locked, :boolean, default: true, if_not_exists: true
  end

  def down
    c = Verse.connection

    if c.column_exists?(:recitations, :segment_locked)
      c.remove_column :recitations, :segment_locked
    end
  end
end
