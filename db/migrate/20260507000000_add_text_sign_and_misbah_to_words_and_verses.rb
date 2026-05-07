class AddTextSignAndMisbahToWordsAndVerses < ActiveRecord::Migration[7.0]
  def change
    c = Word.connection
    c.add_column :words,  :text_sign_language,   :string, if_not_exists: true
    c.add_column :verses, :text_sign_language,   :string, if_not_exists: true
  end
end
