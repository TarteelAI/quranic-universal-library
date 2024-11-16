class AddGroupingToWordTranslation < ActiveRecord::Migration[7.0]
  def change
    c = WordTranslation.connection

    c.add_column :word_translations, :group_text, :string, if_not_exists: true
    c.add_column :word_translations, :group_word_id, :integer, if_not_exists: true
    c.add_index :word_translations, :group_word_id, if_not_exists: true
  end
end
