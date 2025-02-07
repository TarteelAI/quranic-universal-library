class CreateRawDataAyahData < ActiveRecord::Migration[7.0]
  def change
    c = Verse.connection
    c.create_table :raw_data_ayah_records do |t|
      t.integer :verse_id, index: true
      t.text :text
      t.text :text_cleaned
      t.boolean :processed, default: false
      t.integer :raw_resource_id, index: true
      t.string :content_css_class

      t.timestamps
    end
  end
end
