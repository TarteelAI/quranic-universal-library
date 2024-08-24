class RenameTopicChildrenColumn < ActiveRecord::Migration[7.0]
  def change
    c = Topic.connection

    if c.column_exists? :topics, :childen_count
      c.rename_column :topics, :childen_count, :children_count
    end

    add_column :users, :role, :integer, default: 0, if_not_exists: true
  end
end
