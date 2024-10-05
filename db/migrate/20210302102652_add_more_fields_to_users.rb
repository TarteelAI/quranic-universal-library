class AddMoreFieldsToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :about_me, :text
    add_column :user_projects, :admin_notes, :text
  end
end





