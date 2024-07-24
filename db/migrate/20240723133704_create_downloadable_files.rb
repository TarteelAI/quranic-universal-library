class CreateDownloadableFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :downloadable_resources, :language_id, :integer
    create_table :downloadable_files do |t|
      t.references :downloadable_resource, null: false, foreign_key: true
      t.string :name
      t.integer :position, default: 1
      t.integer :download_count, default: 0
      t.string :file_type
      t.string :token, index: true # For download link

      t.timestamps
    end
  end
end
