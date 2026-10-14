# Phase 3, task P3.5: the shared words where the seven printed riwayat disagree.
#
# One row per differing shared word (292 in the pinned quran-text data), with
# the spelling groups and which riwayat lack the word. Drives the CMS review
# queue for glosses (P6.3) and the riwayah comparison tool (P7.2).
class CreateWordDifferences < ActiveRecord::Migration[8.0]
  def up
    c = Verse.connection
    c.create_table :word_differences, primary_key: :word_id do |t|
      t.integer :chapter_id, null: false
      t.string :status, null: false                 # alif_variant | rasm_variant | word_boundary | partial | ...
      t.jsonb :groups, null: false, default: []     # [{text:, riwayahs: [slugs]}]
      t.string :missing, array: true, default: []   # riwayah slugs that do not read the word
      t.string :written_joined, array: true, default: []
      t.jsonb :review, null: false, default: {}     # CMS decisions (P6.3)
      t.timestamps
    end
    c.add_index :word_differences, :chapter_id
    c.add_index :word_differences, :status
  end

  def down
    Verse.connection.drop_table :word_differences
  end
end
