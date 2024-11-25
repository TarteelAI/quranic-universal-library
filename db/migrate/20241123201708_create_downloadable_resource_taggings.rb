class CreateDownloadableResourceTaggings < ActiveRecord::Migration[7.0]
  def change
    create_table :downloadable_resource_taggings do |t|
      t.integer :downloadable_resource_id, null: false
      t.integer :downloadable_resource_tag_id, null: false

      t.index %i[downloadable_resource_id downloadable_resource_tag_id], name: 'index_downloadable_resource_tag'

      t.timestamps
    end
  end
end
