# Stem fixes from users are saved as drafts and go live once approved.
class CreateDraftStems < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_stems do |t|
      t.integer :stem_id, index: true
      t.integer :user_id
      t.string :current_text_madani
      t.string :draft_text_madani
      t.string :current_text_clean
      t.string :draft_text_clean
      t.text :comment
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end
  end
end
