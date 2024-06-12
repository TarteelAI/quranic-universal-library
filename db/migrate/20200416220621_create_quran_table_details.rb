class CreateQuranTableDetails < ActiveRecord::Migration[5.2]
  def change
    create_table :quran_table_details do |t|
      t.string :name
      t.integer :enteries

      t.timestamps
    end
  end
end
