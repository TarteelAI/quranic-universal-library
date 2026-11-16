class CreateShowcaseProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :showcase_projects do |t|
      t.string :name, null: false
      t.string :project_type, null: false, default: 'app'
      t.text :description
      t.string :platforms, array: true, default: []
      t.string :website_url
      t.string :app_store_url
      t.string :play_store_url
      t.string :repository_url
      t.string :owner_name
      t.string :owner_type, default: 'individual'
      t.text :qul_resources_used
      t.integer :user_id, index: true
      t.boolean :published, null: false, default: false, index: true
      t.timestamps
    end
  end
end
