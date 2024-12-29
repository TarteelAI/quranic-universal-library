class CreateQuranScriptByVerses < ActiveRecord::Migration[7.0]
  def change
    c = Verse.connection
    c.create_table :quran_script_by_verses do |t|
      t.string :text, index: true
      t.integer :qirat_id, index: true
      t.integer :resource_content_id, index: true
      t.string :key, index: true
      t.integer :verse_id, index: true

      t.timestamps
    end
  end
end
