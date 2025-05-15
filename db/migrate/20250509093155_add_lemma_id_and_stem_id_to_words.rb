class AddLemmaIdAndStemIdToWords < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.add_column :words, :lemma_id, :integer
    c.add_index :words, :lemma_id

    c.add_column :words, :stem_id, :integer
    c.add_index :words, :stem_id
  end
end
