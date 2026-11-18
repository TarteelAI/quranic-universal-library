# frozen_string_literal: true

# What an app is (`project_type`) moves out of `platforms`, which keeps only where an app runs, and
# an app gets its store and source links beside its main link (`url`). Existing rows: a library,
# tool or dataset key in `platforms` becomes the type and the row's platforms are cleared, since
# only apps have platforms, and an imported row gets the `source_url` of its config/apps.yml entry
# (no row is imported before `apps:import`, so this part does nothing at the production cutover).
# Rollback puts the type back into `platforms` and drops the columns; the platforms cleared from
# non-app rows do not come back.
class AddProjectTypeAndLinksToApps < ActiveRecord::Migration[8.0]
  def up
    change_table :apps, bulk: true do |t|
      t.string :project_type, null: false, default: 'app'
      t.string :app_store_url
      t.string :play_store_url
      t.string :source_url
    end

    execute <<~SQL.squish
      UPDATE apps SET project_type = CASE
        WHEN 'library' = ANY(platforms) THEN 'library'
        WHEN 'dataset' = ANY(platforms) THEN 'data'
        WHEN 'tool' = ANY(platforms) THEN 'tool'
        ELSE 'app' END
    SQL
    execute "UPDATE apps SET platforms = '{}' WHERE project_type <> 'app'"
    add_source_links
  end

  def down
    execute <<~SQL.squish
      UPDATE apps SET platforms = array_append(platforms,
        CASE project_type WHEN 'data' THEN 'dataset' ELSE project_type END)
      WHERE project_type <> 'app'
    SQL
    change_table :apps, bulk: true do |t|
      t.remove :project_type, :app_store_url, :play_store_url, :source_url
    end
  end

  private

  def add_source_links
    YAML.safe_load_file(Rails.root.join('config', 'apps.yml')).fetch('apps').each do |entry|
      next unless entry['source_url']

      sql = 'UPDATE apps SET source_url = ? WHERE import_key = ? AND source_url IS NULL'
      execute ActiveRecord::Base.sanitize_sql_array([sql, entry['source_url'], entry['id']])
    end
  end
end
