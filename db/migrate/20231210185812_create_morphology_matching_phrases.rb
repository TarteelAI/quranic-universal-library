class CreateMorphologyMatchingPhrases < ActiveRecord::Migration[7.0]
  def change
    create_table :morphology_phrases do |t|
      t.string :text_qpc_hafs_simple
      t.string :text_qpc_hafs
      t.integer :source_verse_id, index: true
      t.integer :word_position_from, index: true
      t.integer :word_position_to, index: true
      t.integer :words_count, index: true
      t.integer :chapters_count
      t.integer :verses_count
      t.integer :occurrence
      t.string :review_status, index: true

      t.boolean :approved, index: true, default: false

      t.timestamps
    end
  end
end
