class AddWordsIndexToWords < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.add_column :words, :word_index, :integer, if_not_exists: true
    c.add_index :words, :word_index, if_not_exists: true
  end
end
