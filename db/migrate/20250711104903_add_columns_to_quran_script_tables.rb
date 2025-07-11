class AddColumnsToQuranScriptTables < ActiveRecord::Migration[7.0]
  def change
    c = Verse.connection
    c.change_table :quran_script_by_verses do |t|
      t.integer :chapter_id, index: true
      t.integer :verse_number, index: true
    end

    c.change_table :quran_script_by_words do |t|
      t.integer :chapter_id, index: true
      t.integer :verse_number, index: true
      t.integer :word_number, index: true
    end
  end
end
