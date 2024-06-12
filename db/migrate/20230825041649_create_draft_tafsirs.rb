class CreateDraftTafsirs < ActiveRecord::Migration[7.0]
  def change
    add_column :synonyms, :approved_synonyms, :jsonb, default: []
    create_table :draft_tafsirs do |t|
      t.integer :resource_content_id
      t.integer :tafsir_id, index: true

      t.text :current_text
      t.text :draft_text

      t.boolean :imported, default: false
      t.boolean :need_review, index: true
      t.boolean :text_matched, index: true

      t.integer :verse_id, index: true
      t.string :verse_key, index: true

      t.string :group_verse_key_from
      t.string  :group_verse_key_to
      t.integer :group_verses_count
      t.integer :group_tafsir_id
      t.integer :start_verse_id
      t.integer :end_verse_id

      t.timestamps
    end
  end
end
