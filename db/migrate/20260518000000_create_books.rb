class CreateBooks < ActiveRecord::Migration[8.0]
  def change
    c = ResourceContent.connection

    c.create_table :books do |t|
      t.integer :resource_content_id, index: true
      t.integer :author_id, index: true
      t.string :name
      t.string  :publisher
      t.string  :country
      t.integer :published_year
      t.integer :volumes_count
      t.string  :isbn
      t.string  :source_url
      t.text    :notes
      t.jsonb   :meta_data, default: {}
      t.timestamps
    end
  end
end
