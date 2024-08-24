class AddFilesCountToDownloadableResource < ActiveRecord::Migration[7.0]
  def change
    add_column :downloadable_resources, :files_count, :integer, default: 0, if_not_exists: true
  end
end
