class AddWordMetadata < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.add_column :words, :meta_data, :jsonb, default: {}, if_not_exists: true
  end
end
