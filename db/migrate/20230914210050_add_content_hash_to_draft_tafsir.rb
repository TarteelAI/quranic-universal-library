class AddContentHashToDraftTafsir < ActiveRecord::Migration[7.0]
  def change
    add_column :draft_tafsirs, :md5, :string, index: true
    add_column :draft_tafsirs, :comments, :string, index: true
    add_column :draft_tafsirs, :reviewed, :boolean, index: true
  end
end
