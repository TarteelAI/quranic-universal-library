class AddCopyrightNotice < ActiveRecord::Migration[7.0]
  def change
    ResourcePermission.connection.add_column ResourcePermission.table_name, :copyright_notice, :string
  end
end
