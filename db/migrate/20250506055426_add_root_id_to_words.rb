class AddRootIdToWords < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.add_column :words, :root_id, :integer
    c.add_index :words, :root_id
  end
end
