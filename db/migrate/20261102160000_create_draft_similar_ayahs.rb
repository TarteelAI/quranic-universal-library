# Similar ayah fixes from users are saved as drafts and go live once approved.
class CreateDraftSimilarAyahs < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_similar_ayahs do |t|
      t.integer :verse_id, index: true
      t.integer :chapter_id, index: true
      t.integer :user_id
      t.integer :added_verse_ids, array: true, default: []
      t.integer :removed_verse_ids, array: true, default: []
      t.integer :both_ways_verse_ids, array: true, default: []
      t.text :comment
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end
  end
end
