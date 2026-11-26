# One field orders the apps directory: an app with a `position` is featured and listed first, in
# position order; the others follow by id. Only a super admin sets it in the CMS. The featured
# apps get positions in the order they are listed today (by id), the others none, and `featured`
# is dropped.
# Reversible: a rollback makes the apps with a position featured and drops the column.
class ReplaceFeaturedWithPositionOnApps < ActiveRecord::Migration[8.0]
  def up
    add_column :apps, :position, :integer
    execute <<~SQL.squish
      UPDATE apps SET position = ordered.n
      FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS n FROM apps WHERE featured) ordered
      WHERE apps.id = ordered.id
    SQL
    remove_column :apps, :featured
  end

  def down
    add_column :apps, :featured, :boolean, null: false, default: false
    execute 'UPDATE apps SET featured = TRUE WHERE position IS NOT NULL'
    remove_column :apps, :position
  end
end
