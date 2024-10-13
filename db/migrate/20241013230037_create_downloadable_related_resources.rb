class CreateDownloadableRelatedResources < ActiveRecord::Migration[7.0]
  def change
    create_table :downloadable_related_resources do |t|
      t.integer :downloadable_resource_id
      t.integer :related_resource_id

      t.timestamps
    end
  end
end
