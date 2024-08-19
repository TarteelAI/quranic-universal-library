class RenameTopicChildrenColumn < ActiveRecord::Migration[7.0]
  def change
    c = Topic.connection
    c.rename_column :topics, :childen_count, :children_count

    add_column :users, :role, :integer, default: 0
  end
end
