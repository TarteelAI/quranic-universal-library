class CreateWordMistakes < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.create_table :word_mistakes do |t|
      t.integer :word_id, null: false
      t.integer :mistake_count, null: false, default: 0
      t.float :frequency
      t.text :received_text
      t.integer :char_start, null: true
      t.integer :char_end, null: true

      t.timestamps
    end

    c.add_index :word_mistakes, [:word_id, :char_start, :char_end]
    c.add_index :word_mistakes, :word_id
  end
end
