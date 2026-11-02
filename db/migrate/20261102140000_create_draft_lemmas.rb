# Lemma fixes from users are saved as drafts and go live once approved.
class CreateDraftLemmas < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_lemmas do |t|
      t.integer :lemma_id, index: true
      t.integer :user_id
      t.string :current_text_madani
      t.string :draft_text_madani
      t.string :current_text_clean
      t.string :draft_text_clean
      t.jsonb :current_en_meanings, default: []
      t.jsonb :draft_en_meanings, default: []
      t.text :comment
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end
  end
end
