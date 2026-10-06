# Phase 3, task P3.1: scripts.
#
# A script is one riwayah rendered in one typeface or encoding: KFGQPC Hafs
# unicode, Indopak nastaleeq, the per-page QPC v1 glyph codes, Warsh unicode,
# a tajweed-tagged variant, an image set. Today every script is a column on
# words/verses chosen by name matching; this table makes each one a row that
# says where its text lives (storage) and how it renders (font).
class CreateScripts < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection
    c.create_table :scripts do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.integer :riwayah_id
      t.string :kind, null: false, default: 'unicode'      # unicode | glyph | image
      t.string :storage, null: false, default: 'rows'      # column | rows | legacy
      t.string :column_name                                # storage = column: words/verses column (or Word method for images)
      t.string :font_family                                # CSS @font-face family QUL loads
      t.string :font_css_class                             # class applied to rendered text; glyph scripts use a per-page pattern
      t.string :font_file_url
      t.string :source_package                             # publisher package the text came from
      t.string :source_sha256
      t.string :text_sha256                                # digest of the joined ayah text, for span/timing contracts
      t.integer :release_year
      t.string :licence
      t.integer :word_resource_content_id                  # word-by-word download resource
      t.integer :ayah_resource_content_id                  # ayah-by-ayah download resource
      t.boolean :enabled, null: false, default: true
      t.jsonb :meta_data, null: false, default: {}
      t.timestamps
    end
    c.add_index :scripts, :slug, unique: true
    c.add_index :scripts, :riwayah_id
    c.add_index :scripts, :column_name
  end

  def down
    Verse.connection.drop_table :scripts
  end
end
