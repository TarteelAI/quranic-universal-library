# Ayah theme fixes from users are saved as drafts and go live once approved.
class CreateDraftAyahThemes < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_ayah_themes do |t|
      t.integer :ayah_theme_id, index: true
      t.integer :chapter_id, index: true
      t.integer :user_id
      t.string :current_theme
      t.string :draft_theme
      t.jsonb :current_keywords, default: []
      t.jsonb :draft_keywords, default: []
      t.integer :current_verse_id_from
      t.integer :current_verse_id_to
      t.integer :draft_verse_id_from
      t.integer :draft_verse_id_to
      t.text :comment
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end
  end
end
