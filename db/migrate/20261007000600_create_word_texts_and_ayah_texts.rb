# Phase 3, task P3.2: row storage for script text.
#
# word_texts  the form of one shared word in one script (the source of truth
#             for every script whose storage is "rows"); absence of a row means
#             the riwayah does not read that word
# ayah_texts  cache of the joined ayah text per script, keyed by the numbered
#             ayah. Until phase 4 lands, ayah_id holds the Kufi verse id for
#             Kufi scripts; numbered_ayahs ids coincide with verse ids for the
#             Kufi numbering by construction (P4.2), so no rewrite is needed.
class CreateWordTextsAndAyahTexts < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection
    c.create_table :word_texts, primary_key: %i[script_id word_id] do |t|
      t.integer :script_id, null: false
      t.integer :word_id, null: false
      t.text :text, null: false
      t.text :text_simple
      t.jsonb :marks, null: false, default: []
    end
    c.add_index :word_texts, :word_id

    c.create_table :ayah_texts, primary_key: %i[script_id ayah_id] do |t|
      t.integer :script_id, null: false
      t.integer :ayah_id, null: false
      t.text :text, null: false
    end
  end

  def down
    c = Verse.connection
    c.drop_table :ayah_texts
    c.drop_table :word_texts
  end
end
