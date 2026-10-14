# Phase 7, task P7.5: the last reader of the old names has moved (P1.3 added
# riwayah_id and kept qirat_type_id in step; P7.3 moved the audio tools).
# Drops the qirat_types view (a window on riwayat since P1.2) and the
# qirat_type_id columns of mushafs, recitations and audio_recitations.
# Irreversible for the view's old identity; the columns can be re-added
# from riwayah_id, which `down` does.
class DropLegacyQiratTypes < ActiveRecord::Migration[8.0]
  TABLES = %i[mushafs recitations audio_recitations].freeze

  def up
    c = Verse.connection
    c.execute 'DROP VIEW IF EXISTS qirat_types'
    TABLES.each do |table|
      c.remove_index table, :qirat_type_id if c.index_exists?(table, :qirat_type_id)
      c.remove_column table, :qirat_type_id if c.column_exists?(table, :qirat_type_id)
    end
  end

  def down
    c = Verse.connection
    TABLES.each do |table|
      c.add_column table, :qirat_type_id, :integer
      c.execute "UPDATE #{table} SET qirat_type_id = riwayah_id"
      c.add_index table, :qirat_type_id
    end
    c.execute 'CREATE VIEW qirat_types AS SELECT * FROM riwayat'
  end
end
