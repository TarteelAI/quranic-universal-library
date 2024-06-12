class CreateMorphologyMatchingAyahs < ActiveRecord::Migration[7.0]
  def change
    create_table :morphology_matching_verses do |t|
      t.integer :chapter_id, index: true
      t.integer :verse_id, index: true
      t.integer :words_count, index: true
      t.integer :matched_words_count, index: true
      t.integer :coverage, index: true
      t.integer :score, index: true
      t.jsonb :matched_word_positions, default: []
      t.boolean :approved, index: true

      t.integer :matched_verse_id, index: true
      t.integer :matched_chapter_id, index: true

      t.timestamps
    end
  end
end