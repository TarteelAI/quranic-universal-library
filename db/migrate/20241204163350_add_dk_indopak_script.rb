class AddDkIndopakScript < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection

    c.add_column :words, :text_digital_khatt_indopak, :string
    c.add_column :verses, :text_digital_khatt_indopak, :string
  end
end
