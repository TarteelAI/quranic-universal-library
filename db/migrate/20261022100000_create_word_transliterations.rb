# Word-by-word transliterations move out of the polymorphic `transliterations`
# table into their own table, and `transliterations` gets plain verse columns.
# Data is moved by `rake transliterations:migrate`, the polymorphic columns are
# dropped by the next migration.
class CreateWordTransliterations < ActiveRecord::Migration[8.0]
  def up
    c = Transliteration.connection

    c.create_table :word_transliterations, if_not_exists: true do |t|
      t.integer :word_id, null: false
      t.integer :resource_content_id
      t.integer :language_id
      t.string :language_name
      t.string :text
      t.timestamps
    end

    c.add_index :word_transliterations, :word_id, if_not_exists: true
    c.add_index :word_transliterations, :language_id, if_not_exists: true
    c.add_index :word_transliterations, [:resource_content_id, :word_id], unique: true, if_not_exists: true

    c.add_column :transliterations, :verse_id, :integer, if_not_exists: true
    c.add_column :transliterations, :verse_key, :string, if_not_exists: true
    c.add_column :transliterations, :chapter_id, :integer, if_not_exists: true
    c.add_column :transliterations, :verse_number, :integer, if_not_exists: true

    c.add_index :transliterations, :verse_id, if_not_exists: true
    c.add_index :transliterations, [:resource_content_id, :verse_id], unique: true, if_not_exists: true
  end

  def down
    c = Transliteration.connection

    c.remove_index :transliterations, [:resource_content_id, :verse_id], if_exists: true
    c.remove_index :transliterations, :verse_id, if_exists: true
    %i[verse_id verse_key chapter_id verse_number].each do |column|
      c.remove_column :transliterations, column, if_exists: true
    end

    c.drop_table :word_transliterations, if_exists: true
  end
end
