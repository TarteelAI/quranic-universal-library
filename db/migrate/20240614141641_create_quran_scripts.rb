class CreateQuranScripts < ActiveRecord::Migration[7.0]
  def up
    Verse.connection.create_table :quran_scripts do |t|
      t.string :text
      t.integer :resource_content_id, index: true
      t.string :occurrence_count
      t.string :script_name
      t.string :qirat_name
      t.belongs_to :record, polymorphic: true, index: true

      t.timestamps
    end
  end

  def down
    Verse.connection.drop_table :quran_scripts
  end
end
