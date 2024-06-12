class CreateDatabaseBackups < ActiveRecord::Migration[5.1]
  def change
    create_table :database_backups do |t|
      t.string :database_name
      t.string :file
      t.string :size
      t.string :tag

      t.timestamps
    end
  end
end
