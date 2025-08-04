class AddSegmentDb < ActiveRecord::Migration[7.0]
  def change
   create_table :segments_databases do |t|
      t.string :name
      t.boolean :active, default: false
    end
  end
end
