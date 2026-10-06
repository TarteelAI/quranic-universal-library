# Phase 4, task P4.1: ayah numbering as a layer over the shared words.
#
# ayah_numberings  one concrete sequence of ayah ends: the six madhahib of
#                  'add al-ay, plus a printed numbering wherever an edition
#                  deviates from its madhhab (Susi, 6,218)
# numbered_ayahs   one ayah in one numbering, as a word range with the Kufi
#                  verse range it covers (merged ayahs span two Kufi verses;
#                  split ayahs share one). ayah_number 0 is an unnumbered
#                  basmalah (counted = false)
# ayah_mappings    forward map Kufi verse -> ayah in each numbering,
#                  precomputed so conversion is one primary-key read
class CreateAyahNumberings < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection

    c.create_table :ayah_numberings do |t|
      t.string :slug, null: false              # kufi, madani-last, madani-first, makki, basri, dimashqi, kfgqpc-susi-v3
      t.string :kind, null: false              # madhhab | printed
      t.integer :counting_system_id
      t.string :name_en
      t.string :name_ar
      t.integer :total_ayahs                   # derived from the rows, asserted by verify
      t.string :source                         # dataset or package + version
      t.boolean :basmalah_counted
      t.jsonb :meta_data, null: false, default: {}
      t.timestamps
    end
    c.add_index :ayah_numberings, :slug, unique: true
    c.add_index :ayah_numberings, :counting_system_id

    c.create_table :numbered_ayahs do |t|
      t.integer :numbering_id, null: false
      t.integer :chapter_id, null: false
      t.integer :ayah_number, null: false      # 0 = printed, unnumbered basmalah
      t.string :ayah_key, null: false          # "2:1"
      t.integer :ayah_index                    # global position in this numbering (counted ayahs only)
      t.boolean :counted, null: false, default: true
      t.integer :first_number                  # shared-number range (words.number); ids are not in text order
      t.integer :last_number
      t.integer :first_word_id                 # the words rows carrying those numbers
      t.integer :last_word_id
      t.integer :words_count
      t.integer :kufi_first_verse_id           # anchor range
      t.integer :kufi_last_verse_id
      t.string :relation                       # same | merged | split | shifted | unnumbered (relative to Kufi)
    end
    c.add_index :numbered_ayahs, %i[numbering_id chapter_id ayah_number], unique: true, name: 'index_numbered_ayahs_on_numbering_key'
    c.add_index :numbered_ayahs, %i[numbering_id kufi_first_verse_id], name: 'index_numbered_ayahs_on_numbering_anchor'
    c.add_index :numbered_ayahs, %i[numbering_id ayah_index], name: 'index_numbered_ayahs_on_numbering_index'
    c.add_index :numbered_ayahs, :first_word_id

    c.create_table :ayah_mappings, primary_key: %i[numbering_id verse_id] do |t|
      t.integer :numbering_id, null: false
      t.integer :verse_id, null: false          # Kufi
      t.integer :ayah_id, null: false           # -> numbered_ayahs
      t.integer :ayah_last_id                   # set when the Kufi verse splits
      t.string :relation, null: false           # same | merged | split | shifted | unnumbered
      t.boolean :merges_with_next, null: false, default: false
    end
    c.add_index :ayah_mappings, :ayah_id
  end

  def down
    c = Verse.connection
    c.drop_table :ayah_mappings
    c.drop_table :numbered_ayahs
    c.drop_table :ayah_numberings
  end
end
