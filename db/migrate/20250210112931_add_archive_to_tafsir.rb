class AddArchiveToTafsir < ActiveRecord::Migration[7.0]
  def change
    c = Tafsir.connection
    c.add_column :tafsirs, :archived, :boolean, default: false, if_not_exists: true
  end
end
