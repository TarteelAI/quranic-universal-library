class AddTextToMushafPage < ActiveRecord::Migration[8.0]
  def change
    c = MushafPage.connection
    c.add_column :mushaf_pages, :text, :text
  end
end
