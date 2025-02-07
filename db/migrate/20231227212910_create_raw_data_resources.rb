class CreateRawDataResources < ActiveRecord::Migration[7.0]
  def change
    c = Verse.connection
    c.create_table :raw_data_resources do |t|
      t.string :name
      t.string :key, index: true
      t.string :sub_type, index: true
      t.integer :language_id
      t.string :lang_iso
      t.integer :records_count, default: 0
      t.text :description
      t.integer :resource_content_id
      t.boolean :processed, default: false
      t.string :content_css_class
      t.jsonb :meta_data, default: {}

      t.timestamps
    end
  end
end
