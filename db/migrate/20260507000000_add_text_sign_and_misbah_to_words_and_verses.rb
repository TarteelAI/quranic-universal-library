class AddTextSignAndMisbahToWordsAndVerses < ActiveRecord::Migration[8.0]
  def change
    c = Word.connection

    c.add_column :words,  :text_indonesian_sign_language,   :string, if_not_exists: true
    c.add_column :verses, :text_indonesian_sign_language,   :string, if_not_exists: true

    c.add_column :words,  :text_indopak_misbah,   :string, if_not_exists: true
    c.add_column :verses, :text_indopak_misbah,   :string, if_not_exists: true
  end
end
