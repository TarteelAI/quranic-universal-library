class AddInfoToDownloadableFile < ActiveRecord::Migration[7.0]
  def change
    add_column :downloadable_files, :info, :text
    add_column :downloadable_resources, :meta_data, :jsonb, default: {}
  end
end
