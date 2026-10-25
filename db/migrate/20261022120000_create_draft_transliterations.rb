# Transliteration suggestions get their own draft tables, separate from translation drafts.
class CreateDraftTransliterations < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_transliterations do |t|
      t.integer :resource_content_id, index: true
      t.integer :verse_id, index: true
      t.integer :user_id
      t.text :current_text
      t.text :draft_text
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end

    create_table :draft_word_transliterations do |t|
      t.integer :resource_content_id, index: true
      t.integer :verse_id, index: true
      t.integer :word_id, index: true
      t.string :location, index: true
      t.integer :user_id
      t.string :current_text
      t.string :draft_text
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end
  end
end
