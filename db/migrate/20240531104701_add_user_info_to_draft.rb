class AddUserInfoToDraft < ActiveRecord::Migration[7.0]
  def change
    add_column :draft_tafsirs, :user_id, :integer, index: true
    add_column :draft_translations, :user_id, :integer, index: true
  end
end
