# Catalog fields for the new resource pages. Every column is nullable or has a default, so no
# existing row violates a constraint before the backfills (`bin/rails catalog:backfill`) run.
# Reversible: a rollback drops the columns and constraints.
class AddCatalogFieldsToDownloadableResources < ActiveRecord::Migration[8.0]
  def change
    change_table :downloadable_resources, bulk: true do |t|
      t.string :status, null: false, default: 'stable'
      t.references :superseded_by, foreign_key: { to_table: :downloadable_resources, on_delete: :nullify }
      t.boolean :recommended, null: false, default: false
      t.string :script_family
      t.string :rendering
      t.string :display_name
      t.jsonb :review, null: false, default: {}
    end

    add_check_constraint :downloadable_resources, "status IN ('stable', 'beta', 'legacy', 'superseded')",
                         name: 'downloadable_resources_status'
    add_check_constraint :downloadable_resources, "script_family IN ('madani', 'indopak', 'other')",
                         name: 'downloadable_resources_script_family'
    add_check_constraint :downloadable_resources, "rendering IN ('unicode_font', 'glyph_page', 'image', 'svg')",
                         name: 'downloadable_resources_rendering'
  end
end
