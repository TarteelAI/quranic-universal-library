class CreateResourcePermissions < ActiveRecord::Migration[7.0]
  def change
    create_table :resource_permissions do |t|
      t.integer :resource_content_id
      t.integer :permission_to_host, default: 0
      t.integer :permission_to_share, default: 0

      t.text :permission_to_host_info
      t.text :permission_to_share_info

      t.string :source_info
      t.string :contact_info

      t.timestamps
    end
  end
end
