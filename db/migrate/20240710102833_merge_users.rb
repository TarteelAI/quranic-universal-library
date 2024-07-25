class MergeUsers < ActiveRecord::Migration[7.0]
  def change
    if column_exists?(:important_notes, :admin_user_id)
      rename_column :important_notes, :admin_user_id, :user_id
    end
  end
end
