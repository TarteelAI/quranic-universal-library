class DropWordRootsTable < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.drop_table :word_roots
  end
end
