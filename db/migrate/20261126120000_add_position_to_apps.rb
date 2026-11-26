# The order of the apps directory: featured apps first, then by `position`, then by id. Only a
# super admin sets it in the CMS. Existing rows are numbered in id order, the order they are
# listed in today after the featured ones, so the directory looks the same after the migration.
# Reversible: a rollback drops the column.
class AddPositionToApps < ActiveRecord::Migration[8.0]
  def up
    add_column :apps, :position, :integer
    execute <<~SQL.squish
      UPDATE apps SET position = ordered.n
      FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS n FROM apps) ordered
      WHERE apps.id = ordered.id
    SQL
    change_column_null :apps, :position, false
  end

  def down
    remove_column :apps, :position
  end
end
