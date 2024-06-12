class CreateUserProjects < ActiveRecord::Migration[6.0]
  def change
    create_table :user_projects do |t|
      t.integer :user_id
      t.integer :resource_content_id
      t.text :description

      t.timestamps
    end
  end
end
