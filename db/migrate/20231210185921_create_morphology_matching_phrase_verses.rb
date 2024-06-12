class CreateMorphologyMatchingPhraseVerses < ActiveRecord::Migration[7.0]
  def change
    create_table :morphology_phrase_verses do |t|
      t.integer :phrase_id, index: true
      t.integer :verse_id, index: true
      t.integer :word_position_from, index: true
      t.integer :word_position_to, index: true
      t.integer :matched_words_count, index: true
      t.jsonb :missing_word_positions, default: []
      t.jsonb :similar_words_position, default: []
      t.boolean :approved, index: true
      t.string :review_status, index: true

      t.timestamps
    end

  end
end

