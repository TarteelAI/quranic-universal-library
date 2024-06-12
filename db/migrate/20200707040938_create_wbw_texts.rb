class CreateWbwTexts < ActiveRecord::Migration[5.2]
  def change
    create_table :wbw_texts do |t|
      t.integer :word_id, index: true
      t.integer :verse_id, index: true
      t.string :text_indopak
      t.string :text_uthmani
      t.string :text_imlaei
      t.boolean :is_updated, default: false
      t.boolean :approved, default: false

      t.timestamps
    end
  end
end
