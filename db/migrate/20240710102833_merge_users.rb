class MergeUsers < ActiveRecord::Migration[7.0]
  def change
    rename_column :important_notes, :admin_user_id, :user_id
  end
end
