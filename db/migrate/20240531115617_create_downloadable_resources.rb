class CreateDownloadableResources < ActiveRecord::Migration[7.0]
  def change
    create_table :downloadable_resources do |t|
      t.string :name
      t.integer :resource_content_id
      t.string :resource_type
      t.integer :position, default: 1
      t.string :tags
      t.text :info
      t.string :cardinality_type
      t.boolean :published, default: false

      t.timestamps
    end
  end
end
