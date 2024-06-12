class CreateWordSynonyms < ActiveRecord::Migration[5.2]
  def change
    create_table :word_synonyms do |t|
      t.integer :synonym_id
      t.integer :word_id

      t.timestamps
    end

    add_index :word_synonyms, [:synonym_id, :word_id]
  end
end
