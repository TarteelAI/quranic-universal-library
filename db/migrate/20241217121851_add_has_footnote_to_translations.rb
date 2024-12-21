class AddHasFootnoteToTranslations < ActiveRecord::Migration[7.0]
  def change
    c = Draft::Translation.connection
    c.add_column :draft_translations, :footnotes_count, :integer, default: 0, if_not_exists: true
    c.add_index :draft_translations, :footnotes_count, if_not_exists: true

    c = Translation.connection
    c.add_column :translations, :footnotes_count, :integer, default: 0, if_not_exists: true
    c.add_index :translations, :footnotes_count
  end
end
