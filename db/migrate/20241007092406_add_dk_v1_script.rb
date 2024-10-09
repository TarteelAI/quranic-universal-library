class AddDkV1Script < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.add_column :words, :text_digital_khatt_v1, :string
    c.add_column :verses, :text_digital_khatt_v1, :string
  end
end
