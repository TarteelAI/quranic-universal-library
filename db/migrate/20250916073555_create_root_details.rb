class CreateRootDetails < ActiveRecord::Migration[7.0]
  def change
    c = Verse.connection
    c.drop_table :root_details, if_exists: true

    c.create_table :root_details do |t|
      t.integer :token_id,             index: true
      t.integer :root_id,              index: true
      t.integer :language_id,          index: true
      t.integer :resource_content_id,  index: true
      t.text    :text

      t.jsonb   :meta_data,           default: {}, null: false

      t.timestamps
    end
  end
end
