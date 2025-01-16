class CreateDraftWordTranslations < ActiveRecord::Migration[7.0]
  def change
    create_table :draft_word_translations do |t|
      t.string :draft_text
      t.string :current_text
      t.string :draft_group_text
      t.string :current_group_text

      t.integer :current_group_word_id, index: true
      t.integer :draft_group_word_id, index: true

      t.integer :word_id, index: true
      t.integer :verse_id, index: true
      t.integer :word_translation_id, index: true
      t.integer :language_id, index: true
      t.integer :resource_content_id, index: true
      t.integer :user_id
      t.boolean :text_matched, default: false, index: true
      t.boolean :imported, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.jsonb :meta_data, default: {}
      t.string :location, index: true
      t.integer :word_group_size, default: 1, index: true

      t.timestamps
    end
  end
end
