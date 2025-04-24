class AddSequenceNumberToWords < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.add_column :words, :sequence_number, :integer
    c.add_index :words, :sequence_number, unique: true
  end
end
