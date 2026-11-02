# Root fixes from users are saved as drafts and go live once approved.
class CreateDraftRoots < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_roots do |t|
      t.integer :root_id, index: true
      t.integer :user_id
      t.string :current_arabic_trilateral
      t.string :draft_arabic_trilateral
      t.string :current_english_trilateral
      t.string :draft_english_trilateral
      t.string :current_text_uthmani
      t.string :draft_text_uthmani
      t.jsonb :current_en_meanings, default: []
      t.jsonb :draft_en_meanings, default: []
      t.jsonb :current_ur_meanings, default: []
      t.jsonb :draft_ur_meanings, default: []
      t.text :comment
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end
  end
end
