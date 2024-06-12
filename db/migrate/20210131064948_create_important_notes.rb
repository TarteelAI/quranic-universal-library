class CreateImportantNotes < ActiveRecord::Migration[6.0]
  def change
    create_table :important_notes do |t|
      t.string :title
      t.text :text
      t.string :label

      t.integer :admin_user_id
      t.integer :verse_id
      t.integer :word_id

      t.timestamps
    end
  end
end
