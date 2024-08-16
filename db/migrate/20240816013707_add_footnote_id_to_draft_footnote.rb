class AddFootnoteIdToDraftFootnote < ActiveRecord::Migration[7.0]
  def change
    add_column :draft_foot_notes, :foot_note_id, :integer
    add_index :draft_foot_notes, :foot_note_id

    add_column :draft_translations, :translation_id, :integer
    add_index :draft_translations, :translation_id
  end
end
