class AddLinesCountToMushafPage < ActiveRecord::Migration[7.0]
  def change
    c = MushafPage.connection
    c.add_column :mushaf_pages, :lines_count, :integer
    c.add_index :mushaf_pages, :lines_count
  end
end
