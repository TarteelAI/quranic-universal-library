# Phase 1, task P1.2: qirat_types becomes riwayat.
#
# The table keeps its ids (mushafs, recitations and audio_recitations point at
# them) and gains the columns that make a row a real rawi: a slug, the qiraah
# it transmits, Arabic and English names, an enabled switch and the numbering
# a new mushaf of this riwayah defaults to (filled in phase 4). A plain view
# named qirat_types is left behind for one release so SQL outside the app
# keeps working; the model alias QiratType = Riwayah covers Ruby callers.
class RenameQiratTypesToRiwayat < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection
    c.rename_table :qirat_types, :riwayat
    c.change_table :riwayat do |t|
      t.string :slug
      t.integer :qiraah_id
      t.string :name_ar
      t.string :name_en
      t.boolean :enabled, null: false, default: false
      t.integer :default_numbering_id
      t.jsonb :meta_data, null: false, default: {}
    end
    c.add_index :riwayat, :slug, unique: true
    c.add_index :riwayat, :qiraah_id
    c.add_index :riwayat, :enabled
    c.execute 'CREATE VIEW qirat_types AS SELECT * FROM riwayat'
  end

  def down
    c = Verse.connection
    c.execute 'DROP VIEW IF EXISTS qirat_types'
    c.remove_index :riwayat, :enabled
    c.remove_index :riwayat, :qiraah_id
    c.remove_index :riwayat, :slug
    c.change_table :riwayat do |t|
      t.remove :slug, :qiraah_id, :name_ar, :name_en, :enabled, :default_numbering_id, :meta_data
    end
    c.rename_table :riwayat, :qirat_types
  end
end
