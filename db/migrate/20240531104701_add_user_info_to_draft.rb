class AddUserInfoToDraft < ActiveRecord::Migration[7.0]
  def change
    add_column :draft_tafsirs, :user_id, :integer, if_not_exists: true
    add_index :draft_tafsirs, :user_id, if_not_exists: true
    add_column :draft_translations, :user_id, :integer, if_not_exists: true
    add_index :draft_translations, :user_id, if_not_exists: true
  end
end
