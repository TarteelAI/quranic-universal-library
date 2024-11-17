class AddTextQpcHafsTajweed < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.add_column :words, :text_qpc_hafs_tajweed, :string, if_not_exists: true
    c.add_column :verses, :text_qpc_hafs_tajweed, :string, if_not_exists: true
  end
end
