class CreateDraftContents < ActiveRecord::Migration[7.0]
  def change
    c = Draft::Translation.connection

    c.create_table :draft_contents do |t|
      t.string :text
      t.string :location, index: true
      t.integer :chapter_id, index: true
      t.integer :verse_id, index: true
      t.integer :word_id, index: true
      t.text :draft_text
      t.text :current_text
      t.boolean :imported, index: true
      t.boolean :need_review, index: true
      t.boolean :text_matched, index: true
      t.integer :resource_content_id, index: true
      t.jsonb :meta_data, default: {}

      t.timestamps
    end
  end
end
