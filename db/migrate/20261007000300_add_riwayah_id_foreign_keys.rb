# Phase 1, task P1.3: riwayah_id beside qirat_type_id on the three tables that
# point at a riwayah. The old column stays and is kept in sync by the models
# (HasRiwayah) until phase 7 drops it; this migration only adds, backfills
# and indexes. audio_recitations never had an index on qirat_type_id.
class AddRiwayahIdForeignKeys < ActiveRecord::Migration[8.0]
  TABLES = %i[mushafs recitations audio_recitations].freeze

  def up
    c = Verse.connection
    TABLES.each do |table|
      c.add_column table, :riwayah_id, :integer
      c.execute "UPDATE #{table} SET riwayah_id = qirat_type_id WHERE qirat_type_id IS NOT NULL"
      c.add_index table, :riwayah_id
    end
  end

  def down
    c = Verse.connection
    TABLES.each do |table|
      c.remove_index table, :riwayah_id
      c.remove_column table, :riwayah_id
    end
  end
end
