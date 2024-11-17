class AddResourceCountToDataSource < ActiveRecord::Migration[7.0]
  def change
    c = DataSource.connection
    c.add_column :data_sources, :resource_count, :integer, default: 0, if_not_exists: true
    c.add_column :data_sources, :description, :text, if_not_exists: true
  end
end
