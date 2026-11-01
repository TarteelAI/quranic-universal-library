# Topic fixes from users are saved as drafts and go live once approved.
class CreateDraftTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :draft_topics do |t|
      t.integer :topic_id, index: true
      t.integer :resource_content_id, index: true
      t.integer :user_id
      t.string :current_name
      t.string :draft_name
      t.string :current_arabic_name
      t.string :draft_arabic_name
      t.text :current_description
      t.text :draft_description
      t.integer :added_verse_ids, array: true, default: []
      t.integer :removed_verse_ids, array: true, default: []
      t.text :comment
      t.boolean :text_matched, default: false, index: true
      t.boolean :need_review, default: true, index: true
      t.boolean :imported, default: false, index: true
      t.jsonb :meta_data, default: {}
      t.timestamps
    end
  end
end
