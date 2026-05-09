class AddTextSignAndMisbahToWordsAndVerses < ActiveRecord::Migration[8.0]
  def change
    c = Word.connection

    c.add_column :words,  :text_sign_language,   :string, if_not_exists: true
    c.add_column :verses, :text_sign_language,   :string, if_not_exists: true
  end
end
