class AddUserIdToVersions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :versions, :user_id, :bigint
    add_index :versions, :user_id, algorithm: :concurrently
  end
end
