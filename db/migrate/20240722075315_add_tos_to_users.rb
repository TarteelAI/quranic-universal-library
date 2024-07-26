class AddTosToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :add_to_mailing_list, :boolean, default: false, if_not_exists: true
  end
end
