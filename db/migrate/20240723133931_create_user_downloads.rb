class CreateUserDownloads < ActiveRecord::Migration[7.0]
  def change
    create_table :user_downloads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :downloadable_file, null: false, foreign_key: true
      t.datetime :last_download_at
      t.integer :download_count, default: 0

      t.timestamps
    end
  end
end
