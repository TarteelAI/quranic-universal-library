# Fixes to the root, stem and lemma a word is linked to, saved as drafts and applied once approved.
class CreateDraftWordRoots < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_word_roots do |t|
      t.integer :word_id, index: true
      t.integer :verse_id, index: true
      t.integer :user_id
      t.string :location
      t.integer :current_root_id
      t.integer :draft_root_id
      t.integer :current_stem_id
      t.integer :draft_stem_id
      t.integer :current_lemma_id
      t.integer :draft_lemma_id
      t.text :comment
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end
  end
end
