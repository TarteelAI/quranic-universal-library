class AddTextQpcHafsTajweed < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.add_column :words, :text_qpc_hafs_tajweed, :string
    c.add_column :verses, :text_qpc_hafs_tajweed, :string
  end
end
