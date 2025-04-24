class CreateQuranTableDetails < ActiveRecord::Migration[5.2]
  def change
    ActiveRecord::Migration.create_table :quran_table_details do |t|
      t.string :name
      t.integer :records_count

      t.timestamps
    end
  end
end
