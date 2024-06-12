class AddToggleReviewChanges < ActiveRecord::Migration[7.0]
  def change
    add_column :versions, :reviewed, :boolean, default: false
    add_index :versions, :reviewed
    add_column :versions, :reviewed_by_id, :integer
  end
end
