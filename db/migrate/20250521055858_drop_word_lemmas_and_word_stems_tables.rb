class DropWordLemmasAndWordStemsTables < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.drop_table :word_lemmas
    c.drop_table :word_stems
  end
end
