class AddWordsIndexToWords < ActiveRecord::Migration[7.0]
  def change
    Verse.connection.add_column :words, :word_index, :integer
    Verse.connection.add_index :words, :word_index
  end
end
