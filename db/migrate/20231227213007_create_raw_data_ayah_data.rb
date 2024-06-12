class CreateRawDataAyahData < ActiveRecord::Migration[7.0]
  def change
    create_table :raw_data_ayah_records do |t|
      t.integer :verse_id, index: true
      t.text :text
      t.text :text_cleaned
      t.jsonb :properties, default: {}
      t.boolean :processed, default: false
      t.integer :resource_id
      t.string :content_css_class

      t.timestamps
    end
  end
end
