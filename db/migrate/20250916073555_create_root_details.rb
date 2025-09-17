class CreateRootDetails < ActiveRecord::Migration[7.0]
  def change
    c = Verse.connection
    c.create_table :root_details do |t|
      t.integer :root_id,              index: true, null: false
      t.integer :language_id,          index: true
      t.string  :language_name,        index: true
      t.integer :resource_content_id,  index: true
      t.text    :root_detail

      t.jsonb   :meta_data,           default: {}, null: false

      t.timestamps
    end
  end
end
