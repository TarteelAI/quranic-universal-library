class AddDigitalKhattToNoorBayanTokens < ActiveRecord::Migration[8.0]
  def up
    c = Morphology::Word.connection
    c.add_column :morphology_word_tokens, :text_digital_khatt, :string, if_not_exists: true
    c.add_column :morphology_sentences, :text_digital_khatt, :text, if_not_exists: true
  end

  def down
    c = Morphology::Word.connection
    c.remove_column :morphology_word_tokens, :text_digital_khatt, if_exists: true
    c.remove_column :morphology_sentences, :text_digital_khatt, if_exists: true
  end
end
