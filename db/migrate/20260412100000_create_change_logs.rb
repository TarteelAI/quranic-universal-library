class CreateChangeLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :change_logs do |t|
      t.integer :resource_content_id, null: false
      t.integer :user_id, null: false
      t.string :title, null: false
      t.text :text, null: false
      t.text :excerpt, null: false
      t.boolean :published, null: false, default: false

      t.timestamps
    end

    add_index :change_logs, :resource_content_id
    add_index :change_logs, [:published, :created_at]
  end
end
