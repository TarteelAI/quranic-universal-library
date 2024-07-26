class AddCopyrightNotice < ActiveRecord::Migration[7.0]
  def change
    add_column :resource_permissions, :copyright_notice, :string, if_not_exists: true
  end
end
