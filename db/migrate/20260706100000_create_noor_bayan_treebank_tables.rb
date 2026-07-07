class CreateNoorBayanTreebankTables < ActiveRecord::Migration[8.0]
  def up
    c = Morphology::Word.connection

    c.create_table :morphology_sentences, if_not_exists: true do |t|
      t.integer :sentence_number, null: false
      t.integer :chapter_id
      t.integer :first_verse_id
      t.integer :last_verse_id
      t.integer :verses_count, default: 0
      t.integer :tokens_count, default: 0
      t.integer :words_count, default: 0
      t.text :text_uthmani
      t.text :text_qpc_hafs
      t.timestamps
    end
    c.add_index :morphology_sentences, :sentence_number, unique: true, if_not_exists: true
    c.add_index :morphology_sentences, [:chapter_id, :first_verse_id], if_not_exists: true

    c.create_table :morphology_word_tokens, if_not_exists: true do |t|
      t.integer :sentence_id
      t.integer :word_id
      t.integer :morphology_word_id
      t.integer :root_id
      t.integer :lemma_id
      t.integer :token_type, null: false, default: 0
      t.string :location
      t.integer :chapter_number
      t.integer :verse_number
      t.integer :word_number
      t.integer :position_in_word
      t.integer :position_in_sentence
      t.integer :word_position_in_sentence
      t.string :text_uthmani
      t.string :text_qpc_hafs
      t.string :text_imlaai
      t.string :phonetic
      t.string :translation_en
      t.string :pos_key
      t.string :segment_type
      t.string :lemma_name
      t.string :root_name
      t.string :verb_form
      t.string :verb_aspect
      t.string :verb_mood
      t.string :verb_voice
      t.string :nominal_case
      t.string :nominal_state
      t.string :derived_noun_type
      t.string :special_group
      t.string :prefix_type
      t.string :suffix_type
      t.string :pgn
      t.string :person
      t.string :gender
      t.string :number
      t.string :features
      t.string :rel_label
      t.string :rel_governor
      t.integer :ref_token_position
      t.integer :head_token_id
      t.boolean :dependent_is_phrase, default: false
      t.boolean :head_is_phrase, default: false
      t.integer :is_constituent
      t.integer :constituent_span_start
      t.integer :constituent_span_end
      t.string :constituent_text
      t.string :constituent_label
      t.jsonb :source_meta, default: {}
      t.timestamps
    end

    c.add_index :morphology_word_tokens, [:sentence_id, :position_in_sentence], unique: true, if_not_exists: true
    c.add_index :morphology_word_tokens, :word_id, if_not_exists: true
    c.add_index :morphology_word_tokens, :morphology_word_id, if_not_exists: true
    c.add_index :morphology_word_tokens, :location, if_not_exists: true
    c.add_index :morphology_word_tokens, [:chapter_number, :verse_number], if_not_exists: true
    c.add_index :morphology_word_tokens, :token_type, if_not_exists: true
    c.add_index :morphology_word_tokens, :pos_key, if_not_exists: true
    c.add_index :morphology_word_tokens, :segment_type, if_not_exists: true
    c.add_index :morphology_word_tokens, :rel_label, if_not_exists: true
    c.add_index :morphology_word_tokens, :root_id, if_not_exists: true
    c.add_index :morphology_word_tokens, :lemma_id, if_not_exists: true
    c.add_index :morphology_word_tokens, :head_token_id, if_not_exists: true
  end

  def down
    c = Morphology::Word.connection
    c.drop_table :morphology_word_tokens, if_exists: true
    c.drop_table :morphology_sentences, if_exists: true
  end
end
