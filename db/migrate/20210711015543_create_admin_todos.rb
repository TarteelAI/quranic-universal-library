class CreateAdminTodos < ActiveRecord::Migration[6.1]
  def change
    create_table :admin_todos do |t|
      t.string :description
      t.boolean :is_finished
      t.string :tags
      t.integer :resource_content_id, index: true

      t.timestamps
    end
  end
end