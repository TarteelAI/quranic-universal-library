class AddSlugAndShortSummaryToDownloadableResources < ActiveRecord::Migration[8.0]
  def up
    add_column :downloadable_resources, :slug, :string
    add_column :downloadable_resources, :short_summary, :string
    add_index :downloadable_resources, :slug, unique: true
  end

  def down
    remove_index :downloadable_resources, :slug
    remove_column :downloadable_resources, :short_summary
    remove_column :downloadable_resources, :slug
  end
end
