class CreateQuranScriptByWords < ActiveRecord::Migration[7.0]
  def change
    c = Verse.connection
    c.create_table :quran_script_by_words do |t|
      t.string :text, index: true
      t.string :qirat_id, index: true
      t.string :resource_content_id, index: true
      t.string :key, index: true
      t.string :word_id, index: true
      t.string :verse_id, index: true

      t.timestamps
    end
  end
end
