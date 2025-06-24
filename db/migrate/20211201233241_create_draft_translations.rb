class CreateDraftTranslations < ActiveRecord::Migration[6.1]
  def change
    create_table :draft_translations do |t|
      t.text :draft_text
      t.text :current_text
      t.boolean :text_matched, index: true
      t.integer :verse_id, index: true
      t.integer :resource_content_id, index: true
      t.boolean :need_review, index: true
      t.boolean :imported, default: false, index: true
      t.integer :current_footnotes_count, default: 0

      t.timestamps
    end

    create_table :draft_foot_notes do |t|
      t.text :draft_text
      t.text :current_text
      t.boolean :text_matched, index: true
      t.integer :draft_translation_id, index: true
      t.integer :resource_content_id, true

      t.timestamps
    end
  end
end
