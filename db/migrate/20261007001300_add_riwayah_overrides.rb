# Phase 6, task P6.1: a translation, tafsir or word gloss may differ by
# riwayah only where the reading changes the meaning. A row with riwayah_id
# NULL is the shared text every riwayah reads; a row with a riwayah_id is an
# override for that riwayah of the same (resource, verse|word) key, and the
# readers of P6.2 pick it over the shared row. Nothing is backfilled: NULL
# everywhere means no behaviour change.
#
# The partial unique indexes keep one override per key and riwayah and leave
# the NULL rows alone (the tables carry historical duplicates). translations
# never had the composite (resource_content_id, verse_id) index the readers
# need; with 1.3M rows it is built concurrently, outside a transaction.
class AddRiwayahOverrides < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  TABLES = %i[translations tafsirs word_translations].freeze
  OVERRIDE_KEYS = {
    translations: %i[resource_content_id verse_id riwayah_id],
    tafsirs: %i[resource_content_id verse_id riwayah_id],
    word_translations: %i[word_id resource_content_id riwayah_id]
  }.freeze

  def up
    c = Verse.connection
    TABLES.each do |table|
      c.add_column table, :riwayah_id, :integer
      c.add_index table, OVERRIDE_KEYS[table], unique: true, where: 'riwayah_id IS NOT NULL', name: "index_#{table}_riwayah_override"
    end
    c.add_index :translations, %i[resource_content_id verse_id], algorithm: :concurrently, name: 'index_translations_on_resource_content_id_and_verse_id'
  end

  def down
    c = Verse.connection
    c.remove_index :translations, name: 'index_translations_on_resource_content_id_and_verse_id'
    TABLES.each do |table|
      c.remove_index table, name: "index_#{table}_riwayah_override"
      c.remove_column table, :riwayah_id
    end
  end
end
