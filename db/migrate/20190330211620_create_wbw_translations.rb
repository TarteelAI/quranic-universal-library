class CreateWbwTranslations < ActiveRecord::Migration[5.2]
  def change
    create_table :wbw_translations do |t|
      t.integer :language_id
      t.string :text
      t.integer :user_id
      t.boolean :approved
      t.integer :word_id
      t.string :text_madani
      t.string :text_indopak

      t.integer :chapter_id
      t.integer :verse_id

      t.timestamps
    end
    add_index :wbw_translations, :user_id
    add_index :wbw_translations, :approved
    add_index :wbw_translations, :word_id
    add_index :wbw_translations, :chapter_id
    add_index :wbw_translations, :verse_id
  end
end
