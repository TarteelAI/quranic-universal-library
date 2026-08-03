class AddUserIdToVersions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :versions, :user_id, :bigint
    add_index :versions, :user_id, algorithm: :concurrently

    add_column :user_downloads, :downloadable_resource_id, :bigint
    add_index :user_downloads, :downloadable_resource_id, algorithm: :concurrently
  end
end
